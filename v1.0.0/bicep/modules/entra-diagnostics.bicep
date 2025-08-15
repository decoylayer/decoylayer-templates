@description('Event Hub authorization rule ID')
param eventHubAuthRuleId string

@description('Event Hub name')
param eventHubName string

@description('Event Hub namespace name')
param eventHubNamespaceName string

@description('Azure region')
param location string

// Note: Entra ID diagnostic settings cannot be created via ARM/Bicep as they are tenant-level resources
// This deployment script configures the diagnostic settings using the Graph API
resource entraDiagnosticsScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'entra-diagnostics-setup'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.50.0'
    timeout: 'PT10M'
    retentionInterval: 'PT1H'
    arguments: '${eventHubAuthRuleId} ${eventHubName} ${eventHubNamespaceName}'
    scriptContent: '''
      #!/bin/bash
      set -e
      
      AUTH_RULE_ID=$1
      EVENT_HUB_NAME=$2
      NAMESPACE_NAME=$3
      
      echo "Configuring Entra ID diagnostic settings..."
      echo "Event Hub Auth Rule ID: $AUTH_RULE_ID"
      echo "Event Hub Name: $EVENT_HUB_NAME"
      echo "Namespace Name: $NAMESPACE_NAME"
      
      # Get access token for Microsoft Graph
      echo "Getting access token for Microsoft Graph..."
      TOKEN=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)
      
      # Prepare diagnostic settings payload
      PAYLOAD=$(cat <<EOF
      {
        "name": "DecoylayerDiagnostics",
        "eventHubAuthorizationRuleId": "$AUTH_RULE_ID",
        "eventHubName": "$EVENT_HUB_NAME",
        "logs": [
          {
            "category": "AuditLogs",
            "enabled": true,
            "retentionPolicy": {
              "enabled": false,
              "days": 0
            }
          },
          {
            "category": "SignInLogs",
            "enabled": true,
            "retentionPolicy": {
              "enabled": false,
              "days": 0
            }
          },
          {
            "category": "NonInteractiveUserSignInLogs",
            "enabled": true,
            "retentionPolicy": {
              "enabled": false,
              "days": 0
            }
          },
          {
            "category": "ServicePrincipalSignInLogs",
            "enabled": true,
            "retentionPolicy": {
              "enabled": false,
              "days": 0
            }
          }
        ]
      }
EOF
      )
      
      echo "Payload: $PAYLOAD"
      
      # Configure diagnostic settings using the Graph API
      echo "Creating diagnostic settings..."
      
      # Use the Azure Monitor API for AAD diagnostic settings
      RESPONSE=$(curl -s -X PUT \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettings/DecoylayerDiagnostics?api-version=2021-05-01-preview")
      
      echo "Response: $RESPONSE"
      
      # Check if the request was successful
      if echo "$RESPONSE" | grep -q '"name"'; then
        echo "Diagnostic settings configured successfully!"
      else
        echo "Warning: Could not configure diagnostic settings via API"
        echo "This may need to be configured manually in the Azure portal:"
        echo "1. Go to Azure Active Directory > Monitoring > Diagnostic settings"
        echo "2. Create a new diagnostic setting"
        echo "3. Select all log categories (AuditLogs, SignInLogs, etc.)"
        echo "4. Set destination to Event Hub: $NAMESPACE_NAME/$EVENT_HUB_NAME"
        echo "Response was: $RESPONSE"
      fi
      
      # Alternative: Use Microsoft Graph Change Notifications as fallback
      echo "Note: If diagnostic settings are not available, the Function will configure"
      echo "Microsoft Graph Change Notifications as an alternative data source."
    '''
  }
}

@description('Diagnostic settings configuration result')
output result string = 'Entra ID diagnostic settings configuration attempted. Check deployment script output for status.'