# Changelog - Version 1.0.0

## 🚀 Initial Release (v1.0.0)

*Released: August 2025*

### ✨ New Features

#### Core Infrastructure
- **Azure Function Controller**: Serverless event processing with consumption pricing
- **Event Hub Integration**: Real-time Azure AD log streaming
- **Key Vault Security**: Encrypted storage for HMAC keys and secrets
- **Managed Identity**: Zero-credential authentication for all components

#### Decoy Technologies
- **Service Principal Decoys**: Fake applications with Conditional Access protection
- **VIP Mailbox Decoys**: High-value mailbox honey traps
- **SharePoint Document Traps**: Honey documents with access monitoring
- **Teams Channel Traps**: Teams activity monitoring
- **Key Vault Honey Tokens**: Decoy secrets in Azure Key Vault
- **DevOps Token Decoys**: Fake Azure DevOps personal access tokens

#### Security Features
- **HMAC Authentication**: Cryptographic signing of all alerts
- **Zero SaaS Write Access**: Customer-owned infrastructure only
- **Conditional Access Integration**: Automatic policy creation for decoy protection
- **Least Privilege RBAC**: Minimal required permissions
- **TLS 1.2+ Enforcement**: Encrypted communications only

#### Deployment Features
- **One-Click Azure Portal**: Deploy via custom deployment blade
- **Bicep + ARM Support**: Modern IaC with JSON fallback
- **Parameter Validation**: Built-in parameter checking
- **Deployment Scripts**: PowerShell automation for Entra ID configuration
- **Health Monitoring**: Built-in health checks and monitoring

### 🛡️ Security Model

- **Customer Data Sovereignty**: All data remains in customer tenant
- **Supply Chain Security**: SHA-256 template checksums
- **Audit Trail**: Complete deployment and configuration logging
- **Least Privilege**: Function App limited to `Application.ReadWrite.OwnedBy`
- **Network Security**: Firewall rules and trusted service access

### 📊 Supported Regions

- West Europe (westeurope)
- East US (eastus)
- West US 2 (westus2)
- North Europe (northeurope)

Additional regions available upon request.

### 🔧 Requirements

#### Azure Subscription
- Contributor or Owner permissions
- Azure AD P1/P2 licensing (for Conditional Access)
- Event Hub and Function Apps resource providers registered

#### Entra ID Tenant
- Application Administrator role
- Conditional Access policy creation permissions
- Diagnostic settings configuration access

### 📈 Resource Costs (Estimates)

| Resource Type | Monthly Cost (USD) | Notes |
|---------------|-------------------|-------|
| Function App (Consumption) | $0-5 | Pay-per-execution |
| Event Hub Standard | $10-25 | Includes 1M events |
| Storage Account | $1-5 | Function storage only |
| Key Vault | $1-3 | Secret storage |
| **Total** | **$12-38** | Varies by usage |

*Costs are estimates and may vary by region and usage patterns.*

### 🐛 Known Issues

- Conditional Access policies require Azure AD P1/P2 licensing
- Event Hub in some regions may have longer deployment times
- Function cold start can take 30-60 seconds for first alert

### 📋 Testing

All templates tested with:
- Azure CLI 2.50+
- Azure PowerShell 10.0+
- Azure Portal deployment blade
- Bicep CLI 0.18+

### 🔄 Breaking Changes

None (initial release).

### 📄 Template Checksums

```
main.bicep:     sha256:abcd1234...
main.json:      sha256:efgh5678...
parameters.json: sha256:ijkl9012...
```

Full checksums available in [checksums.txt](checksums.txt).

---

For technical support or questions about this release, please contact support@decoylayer.com or open an issue on GitHub.