@description('Azure region')
param location string

@description('Key Vault name')
param keyVaultName string

@description('Function App managed identity principal ID')
param functionPrincipalId string

@description('Feature configuration')
param features object

@description('Pre-generated HMAC key (optional)')
@secure()
param hmacKey string

@description('Deployment identifier')
param deploymentId string

@description('Resource tags')
param tags object

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

// User-assigned managed identity for deployment script
resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'dl-deploy-${uniqueString(deploymentId)}'
  location: location
  tags: tags
}

// Role assignments for the script identity
// Key Vault Administrator for setting secrets
var keyVaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

resource keyVaultAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, scriptIdentity.id, keyVaultAdministratorRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleId)
    principalId: scriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Note: Entra ID decoys will be created later via Function when Graph permissions are granted

// Deployment script for HMAC generation and infrastructure setup
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'dl-setup-${uniqueString(deploymentId)}'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '9.0'
    timeout: 'PT30M'  // 30 minutes timeout
    retentionInterval: 'PT1H'  // Keep for 1 hour after completion
    arguments: '-KeyVaultName "${keyVaultName}" -FunctionPrincipalId "${functionPrincipalId}" -Features "${base64(string(features))}" -HmacKey "${hmacKey}" -DeploymentId "${deploymentId}" -FunctionAppName "${replace(keyVaultName, '-kv', '-func')}" -ResourceGroupName "${resourceGroup().name}" -SubscriptionId "${subscription().subscriptionId}"'
    scriptContent: '''
      param(
        [string]$KeyVaultName,
        [string]$FunctionPrincipalId,
        [string]$Features,
        [string]$HmacKey,
        [string]$DeploymentId,
        [string]$FunctionAppName,
        [string]$ResourceGroupName,
        [string]$SubscriptionId
      )

      # Import required modules for infrastructure setup
      Import-Module Az.Accounts -Force
      Import-Module Az.KeyVault -Force

      Write-Output "Starting DecoyLayer infrastructure setup for deployment: $DeploymentId"

      try {
        # Verify Azure context
        $context = Get-AzContext
        Write-Output "Authenticated as: $($context.Account.Id)"
        Write-Output "Tenant: $($context.Tenant.Id)"

        # Parse features for logging
        $featuresJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Features))
        $featuresObj = ConvertFrom-Json $featuresJson
        Write-Output "Features selected: $featuresJson"

        # Generate HMAC key if not provided
        if ([string]::IsNullOrEmpty($HmacKey)) {
          Write-Output "Generating HMAC key..."
          $hmacBytes = New-Object byte[] 32
          $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
          $rng.GetBytes($hmacBytes)
          $HmacKey = [Convert]::ToBase64String($hmacBytes)
          $rng.Dispose()
          Write-Output "HMAC key generated successfully"
        } else {
          Write-Output "Using provided HMAC key"
        }

        # Store HMAC in Key Vault
        Write-Output "Storing HMAC key in Key Vault: $KeyVaultName"
        $secret = ConvertTo-SecureString -String $HmacKey -AsPlainText -Force
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "dl-hmac" -SecretValue $secret -ContentType "text/plain"
        Write-Output "HMAC key stored successfully"

        # Sync Function Triggers (fixes Run-From-Package deployment issues)
        Write-Output "Syncing Function triggers for: $FunctionAppName"
        try {
          $syncPath = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$FunctionAppName/syncfunctiontriggers"
          $syncResult = Invoke-AzRestMethod -Method POST -Path $syncPath -ApiVersion "2021-02-01"
          
          if ($syncResult.StatusCode -eq 200 -or $syncResult.StatusCode -eq 204) {
            Write-Output "Function triggers synced successfully"
            
            # Wait for sync to complete
            Start-Sleep -Seconds 10
            
            # Warm-up call to prevent cold start errors
            Write-Output "Performing Function warm-up call..."
            $functionUrl = "https://$FunctionAppName.azurewebsites.net"
            
            # Try warm-up call with retry logic
            $maxRetries = 3
            $retryCount = 0
            $warmupSuccess = $false
            
            while ($retryCount -lt $maxRetries -and -not $warmupSuccess) {
              try {
                $warmupResponse = Invoke-WebRequest -Uri "$functionUrl/admin/host/status" -Method GET -TimeoutSec 30 -ErrorAction Stop
                if ($warmupResponse.StatusCode -eq 200) {
                  Write-Output "Function warm-up successful (Status: $($warmupResponse.StatusCode))"
                  $warmupSuccess = $true
                } else {
                  Write-Warning "Function warm-up returned status: $($warmupResponse.StatusCode)"
                }
              } catch {
                $retryCount++
                Write-Warning "Warm-up attempt $retryCount failed: $($_.Exception.Message)"
                if ($retryCount -lt $maxRetries) {
                  Write-Output "Retrying warm-up in 5 seconds..."
                  Start-Sleep -Seconds 5
                }
              }
            }
            
            if (-not $warmupSuccess) {
              Write-Warning "Function warm-up failed after $maxRetries attempts, but this is not critical for deployment success"
            }
            
          } else {
            Write-Warning "Function trigger sync returned unexpected status: $($syncResult.StatusCode)"
            Write-Warning "Response: $($syncResult.Content)"
          }
        } catch {
          Write-Warning "Failed to sync function triggers: $($_.Exception.Message)"
          Write-Warning "This may cause initial Function portal errors, but Function will work after refresh"
        }

        # Log feature configuration - actual decoy creation happens later via Function
        Write-Output "Infrastructure deployment complete. Feature configuration:"
        if ($featuresObj.identity_decoys -eq $true) {
          Write-Output "  ✓ Identity decoys: Will be created when Graph permissions are granted"
        }
        if ($featuresObj.mailbox_bec -eq $true) {
          Write-Output "  ✓ Mailbox decoys: Will be configured by Function during initialization"
        }
        if ($featuresObj.sharepoint_docs -eq $true) {
          Write-Output "  ✓ SharePoint decoys: Will be configured by Function during initialization"
        }
        if ($featuresObj.teams_trap -eq $true) {
          Write-Output "  ✓ Teams traps: Will be configured by Function during initialization"
        }
        if ($featuresObj.keyvault_honey -eq $true) {
          Write-Output "  ✓ Key Vault honey tokens: Will be created by Function during initialization"
        }
        if ($featuresObj.devops_tokens -eq $true) {
          Write-Output "  ✓ DevOps tokens: Will be configured by Function during initialization"
        }

        # Output results
        $result = @{
          hmacKey = $HmacKey
          deploymentId = $DeploymentId
          featuresConfigured = $featuresObj
          timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC")
          infrastructureReady = $true
        }

        Write-Output "Infrastructure setup completed successfully!"
        Write-Output "HMAC Key stored in Key Vault: $KeyVaultName"
        Write-Output "Function can now start and send health pings"

        # Return structured output
        $DeploymentScriptOutputs = @{
          result = $result
          hmacKey = $HmacKey
          infrastructureReady = $true
        }

      } catch {
        Write-Error "Setup failed: $($_.Exception.Message)"
        Write-Error $_.Exception.StackTrace
        throw
      } finally {
        # Disconnect from Graph
        try {
          Disconnect-MgGraph -ErrorAction SilentlyContinue
        } catch {}
      }
    '''
  }
  dependsOn: [
    keyVaultAdminRoleAssignment
  ]
}

@description('Generated HMAC key')
@secure()
output hmacKey string = deploymentScript.properties.outputs.hmacKey

@description('Infrastructure setup completed')
output infrastructureReady bool = deploymentScript.properties.outputs.infrastructureReady

@description('Deployment script result')
output result object = deploymentScript.properties.outputs.result