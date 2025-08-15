@description('Function App name')
param name string

@description('Azure region')
param location string

@description('App Service Plan ID')
param appServicePlanId string

@description('Storage account name')
param storageAccountName string

@description('Key Vault name')
param keyVaultName string

@description('Event Hub connection string')
@secure()
param eventHubConnectionString string

@description('DecoyLayer ingest endpoint URL')
param relayOutboundUrl string

@description('DecoyLayer customer tenant ID for API validation')
param decoyLayerTenantId string

@description('Resource tags')
param tags object

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: name
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      http20Enabled: true
      functionAppScaleLimit: 10  // Limit scale for cost control
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(name)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: ''  // Can be added later if needed
        }
        // DecoyLayer specific settings
        {
          name: 'DECOYLAYER_INGEST_URL'
          value: relayOutboundUrl
        }
        {
          name: 'DECOYLAYER_TENANT_ID'
          value: decoyLayerTenantId
        }
        {
          name: 'EVENTHUB_CONNECTION_STRING'
          value: eventHubConnectionString
        }
        {
          name: 'KEY_VAULT_NAME'
          value: keyVaultName
        }
        {
          name: 'HMAC_SECRET'
          value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/dl-hmac/)'
        }
        // Will be populated by deployment script
        {
          name: 'DECOY_APP_IDS'
          value: ''
        }
        // Security settings
        {
          name: 'WEBSITE_ENABLE_SYNC_UPDATE_SITE'
          value: 'true'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: 'https://raw.githubusercontent.com/decoylayer/decoylayer-templates/main/customer-function/release/decoylayer-controller.zip'
        }
      ]
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
        supportCredentials: false
      }
      use32BitWorkerProcess: false
      netFrameworkVersion: 'v8.0'
    }
  }
}

@description('Function App name')
output name string = functionApp.name

@description('Function App ID')
output id string = functionApp.id

@description('Function App default hostname')
output functionUrl string = 'https://${functionApp.properties.defaultHostName}'

@description('Function App managed identity principal ID')
output principalId string = functionApp.identity.principalId