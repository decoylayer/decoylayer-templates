@description('App Service Plan name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Y1'      // Consumption plan
    tier: 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    reserved: false  // Windows
  }
}

@description('App Service Plan ID')
output id string = appServicePlan.id

@description('App Service Plan name')
output name string = appServicePlan.name