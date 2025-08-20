// DecoyLayer Infrastructure-as-Code Main Template - Deploys customer-owned components: Function, Event Hub, Key Vault, and decoy objects

targetScope = 'subscription'

// Parameters
@description('DecoyLayer customer tenant ID for API validation and alert routing')
param decoyLayerTenantId string

@description('Azure region for resource deployment')
param location string = 'westeurope'

@description('Feature toggles for different decoy types')
param features object = {
  identity_decoys: true
  mailbox_bec: false
  sharepoint_docs: false
  teams_trap: false
  keyvault_honey: false
  devops_tokens: false
}

@description('DecoyLayer ingest endpoint URL')
param relayOutboundUrl string = 'https://api-dev.decoylayer.com/ingest'

@description('HMAC key for signing alerts (generated if not provided)')
@secure()
param hmacKey string = ''

@description('Resource suffix for unique naming')
param resourceSuffix string = ''

@description('Resource tags')
param tags object = {
  Product: 'DecoyLayer'
  Environment: 'Customer'
  ManagedBy: 'DecoyLayer'
}

@description('Unique deployment identifier')
param deploymentId string = uniqueString(decoyLayerTenantId, resourceSuffix, utcNow())

// Variables
var resourceGroupName = 'dl-${uniqueString(decoyLayerTenantId, resourceSuffix)}-rg'
var keyVaultName = 'dl-${uniqueString(decoyLayerTenantId, resourceSuffix)}-kv'
var eventHubNamespaceName = 'dl-${uniqueString(decoyLayerTenantId, resourceSuffix)}-ehns'
var eventHubName = 'decoylayer-logs'
var functionAppName = 'dl-${uniqueString(decoyLayerTenantId, resourceSuffix)}-func'
var storageAccountName = 'dl${uniqueString(decoyLayerTenantId, resourceSuffix)}st'
var appServicePlanName = 'dl-${uniqueString(decoyLayerTenantId, resourceSuffix)}-plan'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Storage Account (for Function)
module storage './modules/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: storageAccountName
    location: location
    tags: tags
  }
}

// Key Vault
module keyVault './modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: keyVaultName
    location: location
    tags: tags
    tenantId: subscription().tenantId  // Use Azure subscription tenant, not customer tenant
  }
}

// Event Hub Namespace and Hub
module eventHub './modules/eventhub.bicep' = {
  name: 'eventhub'
  scope: rg
  params: {
    namespaceName: eventHubNamespaceName
    eventHubName: eventHubName
    location: location
    tags: tags
  }
}

// App Service Plan (Consumption)
module appServicePlan './modules/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: appServicePlanName
    location: location
    tags: tags
  }
}

// Function App
module functionApp './modules/function.bicep' = {
  name: 'functionapp'
  scope: rg
  params: {
    name: functionAppName
    location: location
    appServicePlanId: appServicePlan.outputs.id
    storageAccountName: storage.outputs.name
    keyVaultName: keyVault.outputs.name
    eventHubConnectionString: eventHub.outputs.connectionString
    relayOutboundUrl: relayOutboundUrl
    decoyLayerTenantId: decoyLayerTenantId
    tags: tags
  }
  dependsOn: [
    storage
    keyVault
    eventHub
    appServicePlan
  ]
}

// Role Assignments
module roleAssignments './modules/roleassignments.bicep' = {
  name: 'roleassignments'
  scope: rg
  params: {
    functionPrincipalId: functionApp.outputs.principalId
    keyVaultName: keyVault.outputs.name
    eventHubNamespaceName: eventHub.outputs.namespaceName
  }
}

// HMAC Key Generation and Storage
module infrastructureSetup './modules/deployment-script.bicep' = {
  name: 'infrastructure-setup'
  scope: rg
  params: {
    location: location
    keyVaultName: keyVault.outputs.name
    functionPrincipalId: functionApp.outputs.principalId
    features: features
    hmacKey: hmacKey
    deploymentId: deploymentId
    tags: tags
  }
  dependsOn: [
    functionApp  // Ensure Function App is fully deployed before running setup script
    roleAssignments  // Ensure all permissions are set up
  ]
}

// Note: Entra ID monitoring handled by Function App via targeted Graph API queries
// No need for tenant-wide diagnostic settings

// Outputs
@description('Resource group name')
output resourceGroupName string = rg.name

@description('Function app name')
output functionName string = functionApp.outputs.name

@description('Function app URL')
output functionUrl string = functionApp.outputs.functionUrl

@description('Key Vault name')
output keyVaultName string = keyVault.outputs.name

@description('Event Hub ID')
output eventHubId string = eventHub.outputs.eventHubId

@description('Deployment ID for tracking')
output deploymentId string = deploymentId

@description('Infrastructure deployment completed')
output infrastructureReady bool = infrastructureSetup.outputs.infrastructureReady

@description('HMAC key for DecoyLayer settings (save immediately)')
@secure()
output hmacKey string = infrastructureSetup.outputs.hmacKey

@description('Template checksum for verification')
output templateChecksum string = uniqueString(string(features), relayOutboundUrl, deploymentId)

@description('Uninstall instructions')
output uninstallInstructions array = [
  '1. Run the cleanup script from the Azure Portal deployment outputs'
  '2. Manually verify all decoy applications are removed from Entra ID'
  '3. Check that Conditional Access policies are deleted'
  '4. Confirm diagnostic settings are disabled'
  '5. Delete the resource group if no other resources are present'
]