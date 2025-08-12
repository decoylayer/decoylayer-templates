# Security Policy

## 🛡️ Hybrid Security Model

DecoyLayer uses a **hybrid security architecture** to balance transparency with operational security:

### Public Components (This Repository)
- Azure infrastructure templates (ARM/Bicep)
- Resource deployment configurations
- Basic Function App scaffolding
- UI definitions for Azure Portal

### Private Components (DecoyLayer SaaS)
- Decoy creation algorithms and patterns
- Naming convention generators
- Detection signature implementations
- Conditional Access policy templates
- Alert correlation logic

## 🔒 What's NOT Exposed

The following are **never** included in public templates:

❌ **Decoy Object Patterns**: How decoy apps/users are named and structured  
❌ **Detection Logic**: What triggers alerts and how they're generated  
❌ **Evasion Signatures**: Patterns that help identify DecoyLayer deployments  
❌ **Correlation Rules**: How alerts are processed and correlated  
❌ **Timing Patterns**: When and how often decoys are rotated  
❌ **Honeypot Configurations**: Specific settings that make decoys effective  

## 🎯 Security Through Dynamic Generation

Each deployment receives:
- **Unique decoy naming patterns** generated per customer
- **Customer-specific detection signatures** 
- **Dynamic rotation schedules**
- **Randomized decoy attributes**
- **Tenant-specific correlation logic**

This ensures attackers cannot:
- Predict decoy patterns across deployments
- Build generic evasion tools
- Fingerprint DecoyLayer infrastructure easily

## 🚨 Reporting Security Issues

**DO NOT** open public GitHub issues for security vulnerabilities.

Instead, email: **security@decoylayer.com**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment
- Your contact information

We'll respond within **24 hours** and work with you on responsible disclosure.

## 🏆 Security Hall of Fame

We recognize security researchers who help improve DecoyLayer:

*Hall of fame coming soon - be the first!*

## 📋 Security Best Practices

When deploying DecoyLayer:

### ✅ Do
- Review and approve all Azure resource deployments
- Use the minimum required Azure permissions
- Monitor Function App logs for unusual activity
- Regularly rotate HMAC keys
- Keep DecoyLayer portal updated

### ❌ Don't
- Share HMAC keys or deployment IDs publicly
- Modify Function App code manually
- Grant excessive Azure permissions
- Disable logging or monitoring
- Deploy in production without testing

## 🔄 Security Updates

- **Critical**: Immediate notification via email + portal
- **Important**: Notification within 24-48 hours
- **Standard**: Included in regular updates

Subscribe to security notifications in your DecoyLayer portal settings.

## 🤝 Responsible Disclosure

We follow a **90-day responsible disclosure policy**:

1. **Day 0**: Report received, acknowledgment sent
2. **Day 7**: Initial assessment and response
3. **Day 30**: Regular progress updates
4. **Day 90**: Public disclosure (if resolved)

Coordinated disclosure timeline may be extended for complex issues.

## 📞 Contact

- **Security Issues**: security@decoylayer.com
- **General Support**: support@decoylayer.com
- **Documentation**: https://docs.decoylayer.com

---

**Last Updated**: August 2025  
**Next Review**: February 2026