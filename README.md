# DecoyLayer Azure Deployment Templates

This repository contains the Infrastructure-as-Code (IaC) templates for deploying DecoyLayer's customer-owned Azure infrastructure.

## 🚀 Quick Deploy

Click the button below to deploy DecoyLayer infrastructure directly to your Azure subscription:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdecoylayer%2Fdecoylayer-templates%2Fmain%2Fv1.0.0%2Fbicep%2Fmain.json)

## 📁 Repository Structure

```
├── v1.0.0/                    # Version 1.0.0 templates
│   ├── bicep/
│   │   ├── main.bicep         # Main Bicep template
│   │   ├── main.json          # Compiled ARM JSON template
│   │   ├── createUiDefinition.json  # Azure Portal UI definition
│   │   ├── parameters.json    # Default parameters
│   │   └── modules/           # Bicep modules
├── latest/                    # Symlink to latest version
├── releases/                  # Release notes and changelogs
└── README.md                  # This file
```

## 🛡️ Security Model

### Zero SaaS Write Access
- All resources are deployed in **your** Azure subscription
- DecoyLayer SaaS has **no write access** to your tenant
- You maintain full control of your infrastructure

### Hybrid Security Architecture
- **Public Templates**: Azure infrastructure deployment (this repository)
- **Private Logic**: Decoy creation patterns and detection signatures (DecoyLayer SaaS)
- **Dynamic Generation**: Unique decoy names and configurations per deployment

### Template Integrity
- Infrastructure templates are signed with SHA-256 checksums
- Versioned releases ensure reproducible deployments
- Public templates contain **no decoy-specific logic** or patterns

## 🏗️ What Gets Deployed

The main template deploys the following Azure resources:

### Core Infrastructure
- **Resource Group**: Contains all DecoyLayer resources
- **Key Vault**: Stores HMAC keys and secrets securely
- **Event Hub**: Receives Azure AD audit and sign-in logs
- **Storage Account**: Required for Azure Function runtime
- **App Service Plan**: Consumption plan for cost-effective execution
- **Function App**: Controller that processes logs and sends alerts

### Security Features
- **Managed Identity**: System-assigned identity for secure access
- **RBAC Roles**: Least-privilege permissions
- **TLS 1.2+**: Encrypted communications only
- **HMAC Authentication**: Cryptographically signed alerts
- **Conditional Access Policies**: Prevents decoy token issuance

### Function App Controller
The deployed Function App receives deployment instructions from DecoyLayer SaaS to:
- Create customer-specific decoy patterns (not exposed in public templates)
- Configure Conditional Access policies with dynamic naming
- Set up diagnostic settings for log streaming
- Generate and store HMAC keys
- Apply unique decoy signatures per deployment

**Security Note**: Decoy creation logic is **not** included in these public templates.

## 🔧 Deployment Options

### Option 1: Azure Portal (Recommended)
1. Click the "Deploy to Azure" button above
2. Sign in to Azure Portal
3. Select subscription and resource group
4. Review parameters and click "Create"

### Option 2: Azure CLI
```bash
# Download template
curl -O https://raw.githubusercontent.com/decoylayer/decoylayer-templates/main/v1.0.0/bicep/main.json

# Deploy
az deployment sub create \
  --location westeurope \
  --template-file main.json \
  --parameters tenantId=your-tenant-id
```

### Option 3: PowerShell
```powershell
# Download template
$templateUri = "https://raw.githubusercontent.com/decoylayer/decoylayer-templates/main/v1.0.0/bicep/main.json"

# Deploy
New-AzDeployment -Location "West Europe" -TemplateUri $templateUri -tenantId "your-tenant-id"
```

## 📊 Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `tenantId` | string | Your Azure AD tenant ID | Required |
| `location` | string | Azure region for deployment | `westeurope` |
| `features` | object | Decoy features to enable | See parameters.json |
| `relayOutboundUrl` | string | DecoyLayer ingest endpoint | `https://portal.decoylayer.com/ingest` |
| `hmacKey` | securestring | HMAC key for alert signing | Auto-generated |

## 🔑 Required Permissions

The deployment identity needs:
- **Subscription**: Contributor or Owner
- **Azure AD**: Application Administrator role
- **Conditional Access**: Policy management permissions

## 🚨 Post-Deployment

After successful deployment:

1. **Save HMAC Key**: Copy from deployment outputs
2. **Configure DecoyLayer**: Paste HMAC key in portal settings
3. **Test Deployment**: Use the built-in test features
4. **Verify Alerts**: Check alert delivery within 5 minutes

## 📈 Monitoring

The deployed infrastructure includes:
- Health endpoints for monitoring
- Application Insights integration
- HMAC-signed alert delivery
- Self-healing capabilities

## 🔄 Updates

To update your deployment:
1. Deploy the latest template version
2. The deployment will update existing resources
3. No data loss or downtime expected

## 🗑️ Uninstallation

To remove all resources:
1. Delete the resource group (removes Azure resources)
2. Remove Entra ID applications via Azure Portal
3. Delete Conditional Access policies
4. Disable diagnostic settings

## 📋 Version History

See [releases/](releases/) for detailed changelogs.

## 🆘 Support

- 📖 **Documentation**: https://docs.decoylayer.com
- 💬 **Community**: https://github.com/decoylayer/decoylayer-templates/discussions
- 🐛 **Issues**: https://github.com/decoylayer/decoylayer-templates/issues
- 📧 **Support**: support@decoylayer.com

## 🔒 Security

For security issues, please email security@decoylayer.com instead of opening a public issue.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**DecoyLayer** - Microsoft-first identity deception platform  
🌐 https://decoylayer.com