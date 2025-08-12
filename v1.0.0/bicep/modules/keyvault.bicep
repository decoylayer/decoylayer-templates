@description('Key Vault for storing HMAC keys and secrets')

@description('Key Vault name')
param name string

@description('Azure region')
param location string

@description('Azure AD tenant ID')
param tenantId string

@description('Resource tags')
param tags object

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: true  // Use RBAC instead of access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 7   // Minimum for production
    enablePurgeProtection: true    // Required for production
    publicNetworkAccess: 'Enabled' // Allow trusted Azure services
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'      // Allow trusted Microsoft services
    }
  }
}

@description('Key Vault name')
output name string = keyVault.name

@description('Key Vault ID')
output id string = keyVault.id

@description('Key Vault URI')
output vaultUri string = keyVault.properties.vaultUri