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

// Application Administrator role for creating Entra apps
var applicationAdministratorRoleId = '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3'

resource entraAppAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, scriptIdentity.id, applicationAdministratorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', applicationAdministratorRoleId)
    principalId: scriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

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

      # Import required modules
      Import-Module Az.Accounts -Force
      Import-Module Az.KeyVault -Force
      Import-Module Microsoft.Graph.Authentication -Force
      Import-Module Microsoft.Graph.Applications -Force
      Import-Module Microsoft.Graph.Identity.SignIns -Force

      Write-Output "Starting DecoyLayer setup for deployment: $DeploymentId"

      try {
        # Connect to Microsoft Graph
        Write-Output "Connecting to Microsoft Graph..."
        $context = Get-AzContext
        Connect-MgGraph -Identity -NoWelcome
        $mgContext = Get-MgContext
        Write-Output "Connected to Graph with tenant: $($mgContext.TenantId)"

        # Parse features
        $featuresJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Features))
        $featuresObj = ConvertFrom-Json $featuresJson
        Write-Output "Features to deploy: $featuresJson"

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

        # Create decoy applications
        $decoyAppIds = @()
        
        if ($featuresObj.identity_decoys -eq $true) {
          Write-Output "Creating identity decoy applications..."
          
          # Create decoy apps with realistic names
          $decoyApps = @(
            @{ Name = "HR-Sync-Service"; Description = "Human Resources synchronization service" },
            @{ Name = "Finance-Analytics"; Description = "Financial analytics and reporting system" },
            @{ Name = "IT-Asset-Manager"; Description = "IT asset management and tracking" }
          )

          foreach ($app in $decoyApps) {
            Write-Output "Creating decoy app: $($app.Name)"
            
            $appParams = @{
              DisplayName = $app.Name
              Description = $app.Description
              SignInAudience = "AzureADMyOrg"
              Tags = @("DecoyLayer", "IdentityDecoy", $DeploymentId)
            }
            
            $newApp = New-MgApplication @appParams
            $decoyAppIds += $newApp.AppId
            Write-Output "Created app: $($newApp.AppId)"

            # Create service principal
            $spParams = @{
              AppId = $newApp.AppId
              Tags = @("DecoyLayer", "IdentityDecoy", $DeploymentId)
            }
            $sp = New-MgServicePrincipal @spParams
            Write-Output "Created service principal: $($sp.Id)"

            # Add Function as owner (for Application.ReadWrite.OwnedBy permissions)
            try {
              $ownerParams = @{
                ApplicationId = $newApp.Id
                BodyParameter = @{
                  "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$FunctionPrincipalId"
                }
              }
              New-MgApplicationOwner @ownerParams
              Write-Output "Added Function as owner of app: $($newApp.AppId)"
            } catch {
              Write-Warning "Failed to add Function as owner: $($_.Exception.Message)"
            }
          }
        }

        if ($featuresObj.mailbox_bec -eq $true) {
          Write-Output "Mailbox BEC feature enabled but requires Exchange Online configuration"
          Write-Output "This will be configured by the Function during initialization"
        }

        if ($featuresObj.sharepoint_docs -eq $true) {
          Write-Output "SharePoint documents feature enabled but requires SharePoint configuration"
          Write-Output "This will be configured by the Function during initialization"
        }

        if ($featuresObj.teams_trap -eq $true) {
          Write-Output "Teams trap feature enabled but requires Teams configuration"
          Write-Output "This will be configured by the Function during initialization"
        }

        if ($featuresObj.keyvault_honey -eq $true) {
          Write-Output "Key Vault honey tokens feature enabled"
          Write-Output "Honey token secrets will be created by the Function during initialization"
        }

        if ($featuresObj.devops_tokens -eq $true) {
          Write-Output "DevOps tokens feature enabled but requires Azure DevOps configuration"
          Write-Output "This will be configured by the Function during initialization"
        }

        # Create Conditional Access policy to block decoy service principals
        if ($decoyAppIds.Count -gt 0) {
          Write-Output "Creating Conditional Access policy to block decoy tokens..."
          
          $policyParams = @{
            DisplayName = "DecoyLayer - Block Token Issuance for Decoys ($DeploymentId)"
            State = "enabled"
            Conditions = @{
              Applications = @{
                IncludeApplications = $decoyAppIds
              }
              ClientApplications = @{
                IncludeServicePrincipals = @("ServicePrincipalsInMyTenant")
              }
            }
            GrantControls = @{
              Operator = "OR"
              BuiltInControls = @("block")
            }
          }
          
          try {
            $caPolicy = New-MgIdentityConditionalAccessPolicy -BodyParameter $policyParams
            Write-Output "Created Conditional Access policy: $($caPolicy.Id)"
          } catch {
            Write-Warning "Failed to create Conditional Access policy: $($_.Exception.Message)"
            Write-Output "Manual creation of CA policy may be required"
          }
        }

        # Output results
        $result = @{
          hmacKey = $HmacKey
          decoyAppIds = $decoyAppIds
          deploymentId = $DeploymentId
          timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC")
        }

        Write-Output "Setup completed successfully!"
        Write-Output "Decoy App IDs: $($decoyAppIds -join ', ')"
        Write-Output "HMAC Key: $HmacKey"

        # Return structured output
        $DeploymentScriptOutputs = @{
          result = $result
          hmacKey = $HmacKey
          decoyAppIds = $decoyAppIds
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
    entraAppAdminRoleAssignment
  ]
}

@description('Generated HMAC key')
@secure()
output hmacKey string = deploymentScript.properties.outputs.hmacKey

@description('Created decoy application IDs')
output decoyAppIds array = deploymentScript.properties.outputs.decoyAppIds

@description('Deployment script result')
output result object = deploymentScript.properties.outputs.result