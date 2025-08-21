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

// Function App Settings - Applied as separate resource for proper startup order
resource functionAppSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: functionApp
  name: 'appsettings'
  properties: {
    // Core Function settings - MUST be present at startup
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
    
    // Azure WebJobs Storage
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
    WEBSITE_CONTENTSHARE: toLower(name)
    
    // Application Insights (optional)
    APPINSIGHTS_INSTRUMENTATIONKEY: ''
    
    // Critical startup settings to prevent "InternalServerError from host runtime"
    WEBSITE_ENABLE_SYNC_UPDATE_SITE: 'true'
    WEBSITE_START_SCM_ON_SITE_CREATION: '1'  // Pre-starts Kudu/SCM
    WEBSITE_USE_PLACEHOLDER: '0'  // Reduces cold start issues
    
    // Run from package
    WEBSITE_RUN_FROM_PACKAGE: 'https://raw.githubusercontent.com/decoylayer/decoylayer-templates/main/customer-function/release/decoylayer-controller.zip'
    
    // DecoyLayer specific settings
    DECOYLAYER_INGEST_URL: relayOutboundUrl
    DECOYLAYER_TENANT_ID: decoyLayerTenantId
    EVENTHUB_CONNECTION_STRING: eventHubConnectionString
    KEY_VAULT_NAME: keyVaultName
    HMAC_SECRET: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/dl-hmac/)'
    
    // Will be populated by deployment script
    DECOY_APP_IDS: ''
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