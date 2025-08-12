# DecoyLayer Azure Bicep Templates

This directory contains the Infrastructure-as-Code (IaC) templates for deploying DecoyLayer's customer-owned components in Azure.

## Architecture

The template creates the following Azure resources:

- **Resource Group**: Contains all DecoyLayer resources
- **Key Vault**: Stores HMAC keys and secrets securely
- **Event Hub**: Receives Azure AD audit and sign-in logs
- **Storage Account**: Required for Azure Function runtime
- **App Service Plan**: Consumption plan for cost-effective serverless execution
- **Function App**: Controller/relay that processes logs and sends alerts
- **Managed Identity**: System-assigned identity for secure resource access
- **Role Assignments**: Least-privilege permissions for Function access

## Security Features

- **Zero SaaS Write Access**: All components are customer-owned
- **HMAC Authentication**: All alerts are cryptographically signed
- **Least Privilege**: Function only gets necessary permissions
- **Secure Defaults**: TLS 1.2+, encrypted storage, RBAC authorization
- **Conditional Access**: Blocks token issuance for decoy service principals
- **Network Security**: Firewall rules and trusted service access

## Deployment Process

1. **Template Generation**: DecoyLayer SaaS generates customized templates
2. **Parameter Injection**: HMAC keys and tenant-specific values are injected
3. **Azure Portal Deployment**: One-click deployment via Azure portal
4. **Post-Deployment Scripts**: Create decoy objects and configure policies
5. **Health Validation**: Verify all components are operational

## Template Structure

```
main.bicep                 # Main subscription-level template
modules/
├── storage.bicep          # Storage account for Function
├── keyvault.bicep         # Key Vault with secure configuration
├── eventhub.bicep         # Event Hub namespace and hub
├── appserviceplan.bicep   # Consumption App Service Plan
├── function.bicep         # Azure Function with app settings
├── roleassignments.bicep  # RBAC role assignments
├── deployment-script.bicep # PowerShell script for decoy creation
└── entra-diagnostics.bicep # Entra ID diagnostic settings
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `tenantId` | string | Azure AD tenant ID for validation |
| `location` | string | Azure region (default: westeurope) |
| `features` | object | Feature flags for decoy types |
| `relayOutboundUrl` | string | DecoyLayer ingest endpoint |
| `hmacKey` | securestring | HMAC key for alert signing |
| `tags` | object | Resource tags for organization |

## Features

The deployment supports the following decoy types:

- **Identity Decoys**: Service principal decoys with CA policies
- **Mailbox BEC**: VIP mailbox decoys (configured post-deployment)
- **SharePoint Docs**: Document honey traps (configured post-deployment) 
- **Teams Trap**: Channel/chat monitoring (configured post-deployment)
- **Key Vault Honey**: Honey token secrets (configured post-deployment)
- **DevOps Tokens**: Azure DevOps PAT decoys (configured post-deployment)

## Deployment Scripts

The template includes PowerShell deployment scripts that:

1. Generate and store HMAC keys in Key Vault
2. Create decoy applications and service principals
3. Set up Conditional Access policies to block decoy tokens
4. Configure Azure AD diagnostic settings for log streaming
5. Assign proper ownership and permissions

## Outputs

After successful deployment, the template outputs:

- Resource group name
- Function app name and URL
- Key Vault name
- Event Hub ID
- Decoy application IDs (non-sensitive)
- HMAC key (one-time display only)
- Deployment instructions

## Permissions Required

The deployment identity needs:

- **Azure RBAC**: Contributor on subscription/resource group
- **Entra ID**: Application Administrator role
- **Key Vault**: Administrator access for secret management
- **Conditional Access**: Policy management permissions

## Monitoring and Maintenance

The deployed Function app includes:

- Health endpoints for monitoring
- Automatic log forwarding to DecoyLayer SaaS
- HMAC-signed alert delivery
- Self-healing capabilities for transient failures

## Uninstallation

To remove all resources:

1. Delete the resource group (removes all Azure resources)
2. Remove decoy applications from Entra ID
3. Delete Conditional Access policies
4. Disable diagnostic settings

## Security Considerations

- HMAC keys are never logged or exposed in deployment history
- All secrets use Azure Key Vault references
- Network access is restricted to trusted Azure services
- Function identity follows least-privilege principles
- All communications use TLS 1.2+ encryption

## Support

For deployment issues or questions, contact DecoyLayer support or check the troubleshooting guide in the main documentation.