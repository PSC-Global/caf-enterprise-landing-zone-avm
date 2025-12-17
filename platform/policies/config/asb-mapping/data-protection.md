# Azure Security Benchmark - Data Protection Domain Control Mapping

## Overview
This document maps Azure Security Benchmark v3 data protection controls to built-in policy definitions. Use this as a reference for understanding ASB data protection requirements and planning encryption, backup, and data loss prevention strategies.

## Control Family: Data Protection (DP)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| DP-1 | Discover, classify, and label sensitive data | Implement data classification and labeling | Enable Azure Purview/Microsoft Purview | Platform Management: Phase 2, LZ MGs: Phase 3 |
| DP-2 | Monitor anomalies and threats targeting sensitive data | Monitor for unauthorized data access and exfiltration | Enable threat detection on storage accounts, SQL | Platform Management: Enforce, LZ MGs: Phase 1 |
| DP-3 | Encrypt sensitive data in transit | Use TLS 1.2+ for all data in transit | Require secure transfer for storage accounts, enforce TLS 1.2+ | All MGs: Enforce |
| DP-4 | Enable data at rest encryption by default | Encrypt all data at rest using platform-managed or customer-managed keys | Enable encryption on storage, SQL, disks | All MGs: Enforce (PMK), Phase 2 (CMK) |
| DP-5 | Use customer-managed key option in data at rest encryption | Implement CMK where required for compliance | Require CMK for storage, SQL, Key Vault | Corp LZ: Phase 2, Online LZ: Phase 3 |
| DP-6 | Use a secure key management process | Manage encryption keys securely in Azure Key Vault | Store keys in Key Vault, enable soft delete, purge protection | All MGs: Enforce |
| DP-7 | Use a secure certificate management process | Manage certificates through Azure Key Vault | Store certificates in Key Vault, enable auto-rotation | Platform Identity: Enforce, LZ MGs: Phase 1 |
| DP-8 | Ensure security of key and certificate repository | Secure Key Vault with private endpoints, RBAC, and network restrictions | Require private endpoint for Key Vault, enable firewall | Platform Identity: Enforce, LZ MGs: Phase 1 |

## Control Family: Backup and Recovery (BR)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| BR-1 | Ensure regular automated backups | Implement automated backup for critical resources | Enable Azure Backup for VMs, SQL, file shares | All LZ MGs: Enforce, Platform MGs: Phase 1 |
| BR-2 | Protect backup and recovery data | Secure backup data with encryption and access controls | Enable soft delete for Recovery Services Vault | All MGs: Enforce |
| BR-3 | Monitor backup and recovery operations | Monitor backup success and failure events | Send backup alerts to Log Analytics | Platform Management: Enforce, LZ MGs: Phase 1 |
| BR-4 | Regularly test backup restoration | Validate backup integrity through restoration testing | Manual validation process (not policy-enforced) | All MGs: Operational requirement |

## Phased Enforcement Strategy

### Phase 1: Critical Data Protection (Immediate)
- DP-3: TLS encryption in transit (all MGs)
- DP-4: Encryption at rest with PMK (all MGs)
- DP-6: Key management in Key Vault (all MGs)
- DP-8: Key Vault security (Platform Identity, critical workloads)
- BR-1: Automated backups (landing zones)
- BR-2: Backup data protection (all MGs)

### Phase 2: Enhanced Data Security (30-60 days)
- DP-1: Data classification (Platform Management)
- DP-2: Threat detection (all MGs)
- DP-5: Customer-managed keys (Corp LZ)
- DP-7: Certificate management (all MGs)
- BR-3: Backup monitoring (all MGs)

### Phase 3: Advanced Data Governance (60-90 days)
- DP-1: Data classification rollout (all LZ MGs)
- DP-5: CMK requirements (Online LZ)
- BR-4: Backup restoration testing program

## Management Group Specific Guidance

### Platform Identity
- **Data Protection Priority**: Highest
- **Key Focus**: Key Vault security, certificate management
- **Requirements**:
  - Key Vault with private endpoints
  - Soft delete and purge protection enabled
  - RBAC-based access (no access policies)
  - Certificate auto-rotation
  - Network restrictions (no public access)
  - CMK for Key Vault encryption

### Platform Management
- **Data Protection Priority**: High
- **Key Focus**: Log data protection, backup monitoring
- **Requirements**:
  - Log Analytics workspace encryption
  - Storage account encryption (PMK minimum)
  - Backup monitoring for infrastructure
  - Data classification tooling (Purview)

### Platform Connectivity
- **Data Protection Priority**: Medium
- **Key Focus**: Network configuration backup
- **Requirements**:
  - Backup for VPN/ExpressRoute configs
  - Key Vault for certificate management
  - Encryption for network traffic (handled by NS controls)

### Corp Landing Zones
- **Data Protection Priority**: Very High
- **Key Focus**: CMK, backups, data classification
- **Requirements**:
  - CMK for SQL databases, storage accounts
  - Azure Backup for all VMs and databases
  - Soft delete enabled on storage accounts
  - Private endpoints for storage and Key Vault
  - Data classification for sensitive workloads
  - Immutable blob storage for audit logs

### Online Landing Zones
- **Data Protection Priority**: High
- **Key Focus**: TLS enforcement, backups, DLP
- **Requirements**:
  - TLS 1.2+ on all public endpoints
  - Azure Backup for stateful services
  - Storage account public access restrictions
  - CMK for sensitive data workloads
  - DLP policies for internet-facing apps

## Data Classification Framework

### Sensitivity Levels
| Level | Description | Encryption | Backup | Access |
|-------|-------------|-----------|---------|---------|
| Public | Non-sensitive, publicly available | PMK | Optional | Open |
| Internal | Business information | PMK | Required | Authenticated users |
| Confidential | Sensitive business data | CMK | Required + immutable | Role-based |
| Highly Confidential | Regulated, personal data | CMK + additional controls | Required + immutable + offsite | Restricted RBAC + MFA |

## Encryption Requirements by Service

### Storage Accounts
- **Encryption at Rest**: Enforce (infrastructure encryption enabled)
- **Encryption in Transit**: Enforce (HTTPS only, TLS 1.2+)
- **CMK Requirement**: Corp LZ (Phase 2), Online LZ (Phase 3)
- **Additional**: Soft delete, versioning, immutable storage for audit logs

### Azure SQL Database
- **Encryption at Rest**: Enforce (TDE enabled)
- **Encryption in Transit**: Enforce (SSL/TLS required)
- **CMK Requirement**: Corp LZ (Phase 2), Online LZ (Phase 3)
- **Additional**: Always Encrypted for sensitive columns, backup encryption

### Virtual Machine Disks
- **Encryption at Rest**: Enforce (Azure Disk Encryption or SSE with PMK)
- **CMK Requirement**: Confidential VMs, highly sensitive workloads
- **Additional**: Disk snapshots encrypted

### Key Vault
- **Encryption at Rest**: Enforce
- **Soft Delete**: Enforce (90-day retention)
- **Purge Protection**: Enforce for production Key Vaults
- **Network**: Private endpoints required (Platform Identity, Corp LZ)

## Backup Strategy by Workload Type

### Virtual Machines
- **Policy**: Daily backups, 30-day retention
- **Implementation**: Azure Backup with Recovery Services Vault
- **Enforcement**: Enforce in Corp and Online LZ MGs

### Azure SQL Database
- **Policy**: Automated backups with point-in-time restore (7-35 days)
- **Implementation**: Built-in SQL backup with LTR for compliance
- **Enforcement**: Audit to ensure not disabled

### Storage Accounts (File Shares)
- **Policy**: Azure Backup for Azure Files, 30-day retention
- **Implementation**: Recovery Services Vault backup
- **Enforcement**: Enforce for production storage accounts

### Application Configuration/State
- **Policy**: Export configs to storage with versioning
- **Implementation**: Infrastructure as Code (Bicep) in Git, Key Vault for secrets
- **Enforcement**: Operational process (not policy-based)

## Key Vault Security Configuration

### Required Settings
```bicep
{
  enableSoftDelete: true
  softDeleteRetentionInDays: 90
  enablePurgeProtection: true
  enableRbacAuthorization: true
  networkAcls: {
    defaultAction: 'Deny'
    bypass: 'AzureServices'
  }
  privateEndpointRequired: true
}
```

### Access Patterns
- **Production**: Private endpoint only, RBAC-based access, conditional access policies
- **Development**: May use public access with IP restrictions, RBAC still required
- **Secrets Access**: Managed identities only (no service principal secrets)

## References
- [Azure Data Encryption at Rest](https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-atrest)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [Azure Backup Documentation](https://learn.microsoft.com/en-us/azure/backup/)
- [Customer-Managed Keys](https://learn.microsoft.com/en-us/azure/storage/common/customer-managed-keys-overview)
