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

// Deployment script for HMAC generation and decoy creation
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
    arguments: '-KeyVaultName "${keyVaultName}" -FunctionPrincipalId "${functionPrincipalId}" -Features "${base64(string(features))}" -HmacKey "${hmacKey}" -DeploymentId "${deploymentId}"'
    scriptContent: '''
      param(
        [string]$KeyVaultName,
        [string]$FunctionPrincipalId,
        [string]$Features,
        [string]$HmacKey,
        [string]$DeploymentId
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

@description('Created decoy application IDs')
output decoyAppIds array = deploymentScript.properties.outputs.decoyAppIds

@description('Deployment script result')
output result object = deploymentScript.properties.outputs.result