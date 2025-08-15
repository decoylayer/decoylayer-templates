@description('Event Hub namespace name')
param namespaceName string

@description('Event Hub name')
param eventHubName string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'  // Needed for Azure diagnostic settings
    disableLocalAuth: false         // Required for diagnostic settings auth
    zoneRedundant: false           // Standard tier doesn't support zone redundancy
    kafkaEnabled: false
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 1      // Minimum retention for cost optimization
    partitionCount: 2              // Standard tier minimum
    status: 'Active'
  }
}

// Authorization rule for sending (used by diagnostic settings)
resource sendAuthRule 'Microsoft.EventHub/namespaces/authorizationRules@2022-10-01-preview' = {
  parent: eventHubNamespace
  name: 'SendRule'
  properties: {
    rights: [
      'Send'
    ]
  }
}

// Authorization rule for listening (used by Function)
resource listenAuthRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-10-01-preview' = {
  parent: eventHub
  name: 'ListenRule'
  properties: {
    rights: [
      'Listen'
    ]
  }
}

// Consumer group for the Function
resource consumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2022-10-01-preview' = {
  parent: eventHub
  name: 'decoylayer-function'
}

@description('Event Hub namespace name')
output namespaceName string = eventHubNamespace.name

@description('Event Hub name')
output name string = eventHub.name

@description('Event Hub resource ID')
output eventHubId string = eventHub.id

@description('Send authorization rule ID for diagnostic settings')
output authRuleId string = sendAuthRule.id

@description('Listen connection string for Function')
output connectionString string = listenAuthRule.listKeys().primaryConnectionString

@description('Consumer group name')
output consumerGroupName string = consumerGroup.name