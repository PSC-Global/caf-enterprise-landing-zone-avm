# Azure Security Benchmark - Storage Security Domain Control Mapping

## Overview
This document maps Azure Security Benchmark v3 storage security controls to built-in policy definitions for Azure Storage Accounts, managed disks, and other storage services.

## Control Family: Storage Security (SS)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| SS-1 | Enable encryption at rest | Encrypt all storage data at rest with platform or customer-managed keys | Require encryption on storage accounts | All MGs: Enforce |
| SS-2 | Enable encryption in transit | Require HTTPS/TLS for all storage connections | Require secure transfer (HTTPS only) | All MGs: Enforce |
| SS-3 | Use private endpoints for storage | Disable public access and use private endpoints | Require private endpoints for storage | Corp LZ: Enforce, Online LZ: Phase 1 |
| SS-4 | Enable soft delete and versioning | Protect against accidental deletion with soft delete | Enable soft delete for blobs and containers | All MGs: Enforce |
| SS-5 | Use immutable storage for compliance | Implement WORM (Write Once, Read Many) for audit logs | Enable immutability for audit/compliance data | Platform Management: Enforce, LZ MGs: Phase 2 |
| SS-6 | Enable threat detection | Monitor for anomalous storage access patterns | Enable Defender for Storage | All MGs: Enforce |
| SS-7 | Restrict storage account key access | Use Azure AD authentication, disable shared key access | Disable shared key authorization | Corp LZ: Phase 2, Online LZ: Phase 3 |
| SS-8 | Enable logging for storage operations | Log all storage access for audit and investigation | Enable diagnostic settings for storage | All MGs: Enforce |

## Control Family: Disk Encryption (DE)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| DE-1 | Encrypt OS disks | Enable encryption on all VM OS disks | Require disk encryption for VMs | All LZ MGs: Enforce |
| DE-2 | Encrypt data disks | Enable encryption on all VM data disks | Require disk encryption for data disks | All LZ MGs: Enforce |
| DE-3 | Use customer-managed keys for disks | Use CMK from Key Vault for disk encryption | Require CMK for sensitive VMs | Corp LZ: Phase 2 |
| DE-4 | Enable double encryption | Apply double encryption for highly sensitive data | Enable infrastructure encryption | Corp LZ (sensitive): Phase 2 |

## Phased Enforcement Strategy

### Phase 1: Critical Storage Security (Immediate)
- SS-1: Encryption at rest (all MGs)
- SS-2: HTTPS only (all MGs)
- SS-4: Soft delete (all MGs)
- SS-6: Threat detection (all MGs)
- SS-8: Storage logging (all MGs)
- DE-1: OS disk encryption (all LZ MGs)
- DE-2: Data disk encryption (all LZ MGs)

### Phase 2: Enhanced Storage Security (30-60 days)
- SS-3: Private endpoints (Corp LZ)
- SS-5: Immutable storage (audit logs)
- SS-7: Disable shared key access (Corp LZ)
- DE-3: CMK for disks (Corp LZ sensitive workloads)
- DE-4: Double encryption (Corp LZ highly sensitive)

### Phase 3: Advanced Storage Security (60-90 days)
- SS-3: Private endpoints (Online LZ)
- SS-5: Immutable storage (all compliance workloads)
- SS-7: Disable shared key access (Online LZ)
- Full CMK adoption for regulated data

## Management Group Specific Guidance

### Platform Identity
- **Storage Resources**: Key Vault (secret storage), minimal blob storage
- **Requirements**:
  - Private endpoints for Key Vault
  - No public blob storage access
  - CMK where applicable
  - Soft delete + purge protection
  - Logging to central Log Analytics

### Platform Management
- **Storage Resources**: Log storage, backup storage, automation storage
- **Requirements**:
  - Immutable storage for logs (1-7 year retention)
  - Private endpoints for backup vaults
  - Soft delete enabled (90 days)
  - Threat detection enabled
  - GRS or GZRS for backup data
  - Lifecycle management for cost optimization

### Platform Connectivity
- **Storage Resources**: Network diagnostic logs
- **Requirements**:
  - Append-only blob storage for NSG flow logs
  - Private endpoints preferred
  - Retention aligned with compliance (90+ days)

### Corp Landing Zones
- **Storage Resources**: Application data, databases, file shares
- **Requirements**:
  - Private endpoints mandatory
  - Public network access disabled
  - Soft delete enabled (30-90 days)
  - CMK for sensitive data (PII, financial)
  - Azure AD authentication preferred
  - Backup enabled (Azure Backup or built-in)
  - Versioning for critical data
  - Immutable storage for audit logs

### Online Landing Zones
- **Storage Resources**: Web assets, API data, CDN origin
- **Requirements**:
  - Private endpoints for backend storage
  - Public access allowed only for CDN-served content
  - Soft delete enabled (7-30 days)
  - Azure Front Door/CDN integration
  - Threat detection enabled
  - DDoS protection for public storage
  - CMK for user data

## Storage Account Security Configuration

### Standard Configuration (Non-Sensitive Data)
```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'stprodauecorp01'
  location: location
  sku: {
    name: 'Standard_GRS'  // Geo-redundancy for disaster recovery
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true  // Enforce HTTPS
    allowBlobPublicAccess: false    // Disable anonymous access
    allowSharedKeyAccess: true      // Phase 2: Set to false for AAD only
    publicNetworkAccess: 'Disabled' // Corp LZ: Private endpoints only
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    encryption: {
      services: {
        blob: { enabled: true }
        file: { enabled: true }
      }
      keySource: 'Microsoft.Storage'  // PMK, upgrade to CMK in Phase 2
    }
  }
}

// Soft delete configuration
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    isVersioningEnabled: true  // Enable versioning
  }
}
```

### Enhanced Configuration (Sensitive Data)
```bicep
resource storageAccountSensitive 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'stprodauecorpsensitive'
  location: location
  sku: {
    name: 'Standard_GZRS'  // Zone-redundancy + geo-redundancy
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false     // AAD authentication only
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'  // No Azure service bypass
    }
    encryption: {
      services: {
        blob: { enabled: true }
        file: { enabled: true }
        queue: { enabled: true }
        table: { enabled: true }
      }
      keySource: 'Microsoft.Keyvault'  // CMK
      keyvaultproperties: {
        keyname: 'storage-cmk-key'
        keyvaulturi: 'https://kv-prod-aue-platform.vault.azure.net'
      }
      requireInfrastructureEncryption: true  // Double encryption
    }
  }
  identity: {
    type: 'SystemAssigned'  // For CMK access to Key Vault
  }
}

// Extended soft delete and immutability
resource blobServicesSensitive 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccountSensitive
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 90  // Extended retention for sensitive data
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 90
    }
    isVersioningEnabled: true
    changeFeed: {
      enabled: true
      retentionInDays: 90
    }
  }
}

// Immutable policy for compliance container
resource immutableContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobServicesSensitive
  name: 'audit-logs'
  properties: {
    immutableStorageWithVersioning: {
      enabled: true
    }
  }
}
```

## Private Endpoint Configuration

### Storage Account Private Endpoints
Each storage service requires separate private endpoint:

```bicep
// Blob storage private endpoint
resource privateEndpointBlob 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: 'pe-blob-${storageAccount.name}'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [{
      name: 'blob-connection'
      properties: {
        privateLinkServiceId: storageAccount.id
        groupIds: ['blob']
      }
    }]
  }
}

// Private DNS zone integration
resource privateDnsZoneLink 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  parent: privateEndpointBlob
  name: 'blob-dns-group'
  properties: {
    privateDnsZoneConfigs: [{
      name: 'blob-config'
      properties: {
        privateDnsZoneId: blobPrivateDnsZone.id
      }
    }]
  }
}
```

### Supported Storage Services
- **blob**: `privatelink.blob.core.windows.net`
- **file**: `privatelink.file.core.windows.net`
- **queue**: `privatelink.queue.core.windows.net`
- **table**: `privatelink.table.core.windows.net`
- **dfs**: `privatelink.dfs.core.windows.net` (Data Lake Gen2)

## Managed Disk Encryption

### Azure Disk Encryption (BitLocker/dm-crypt)
```bicep
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  properties: {
    storageProfile: {
      osDisk: {
        encryptionSettings: {
          enabled: true
          diskEncryptionKey: {
            sourceVault: {
              id: keyVault.id
            }
            secretUrl: diskEncryptionSecret.properties.secretUri
          }
          keyEncryptionKey: {
            sourceVault: {
              id: keyVault.id
            }
            keyUrl: keyEncryptionKey.properties.keyUriWithVersion
          }
        }
      }
    }
  }
}
```

### Server-Side Encryption with CMK
```bicep
resource diskEncryptionSet 'Microsoft.Compute/diskEncryptionSets@2023-01-02' = {
  name: 'des-prod-aue-corp'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    activeKey: {
      keyUrl: keyVaultKey.properties.keyUriWithVersion
      sourceVault: {
        id: keyVault.id
      }
    }
    encryptionType: 'EncryptionAtRestWithPlatformAndCustomerKeys'  // Double encryption
  }
}

// Use in managed disk
resource disk 'Microsoft.Compute/disks@2023-01-02' = {
  name: 'disk-data-prod-01'
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 1024
    encryption: {
      type: 'EncryptionAtRestWithPlatformAndCustomerKeys'
      diskEncryptionSetId: diskEncryptionSet.id
    }
  }
}
```

## Defender for Storage Configuration

### Enable Threat Protection
```bicep
resource defenderForStorage 'Microsoft.Security/pricings@2023-01-01' = {
  name: 'StorageAccounts'
  properties: {
    pricingTier: 'Standard'
    subPlan: 'DefenderForStorageV2'  // Latest version
    extensions: [{
      name: 'OnUploadMalwareScanning'
      isEnabled: 'True'
      additionalExtensionProperties: {
        CapGBPerMonthPerStorageAccount: '5000'  // Monthly scanning cap
      }
    }, {
      name: 'SensitiveDataDiscovery'
      isEnabled: 'True'
    }]
  }
}
```

### Alert Types
- **Unusual access patterns**: Access from anonymous IP, TOR exit node
- **Data exfiltration**: Large volume downloads
- **Malware upload**: Malicious file detected
- **Credential leak**: Storage account key exposed in public repo
- **Sensitive data discovery**: PII/PHI detected in blobs

## Storage Lifecycle Management

### Automated Tiering
```json
{
  "rules": [{
    "name": "move-to-cool-after-30-days",
    "enabled": true,
    "type": "Lifecycle",
    "definition": {
      "actions": {
        "baseBlob": {
          "tierToCool": {
            "daysAfterModificationGreaterThan": 30
          },
          "tierToArchive": {
            "daysAfterModificationGreaterThan": 365
          },
          "delete": {
            "daysAfterModificationGreaterThan": 2555
          }
        }
      },
      "filters": {
        "blobTypes": ["blockBlob"],
        "prefixMatch": ["logs/"]
      }
    }
  }]
}
```

### Cost Optimization
- **Hot Tier**: Frequently accessed data (< 30 days)
- **Cool Tier**: Infrequently accessed (30-365 days), lower storage cost
- **Archive Tier**: Long-term retention (> 365 days), lowest cost
- **Delete**: Compliance period expired (7 years for financial data)

## Azure Files Security

### SMB Security Settings
```bicep
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    protocolSettings: {
      smb: {
        versions: 'SMB3.0;SMB3.1.1'  // Only secure SMB versions
        authenticationMethods: 'Kerberos'
        kerberosTicketEncryption: 'AES-256'
        channelEncryption: 'AES-256-GCM'
      }
    }
  }
}
```

### Azure AD DS Integration
- Join storage account to Azure AD DS
- Use AD credentials for file share access
- NTFS permissions for granular access control
- No storage account key access needed

## Monitoring and Alerts

### Critical Storage Alerts
1. **Storage account key regenerated**: Potential credential compromise
2. **Public access enabled**: Security policy violation
3. **Malware detected**: Infected file uploaded
4. **Unusual data egress**: Potential exfiltration (> 100 GB/hour)
5. **TLS downgrade detected**: Insecure connection attempt
6. **Failed authentication spike**: Potential brute force attack

### Storage Metrics Dashboard
- Storage capacity utilization
- Transaction volume and latency
- Availability and error rates
- Egress bandwidth (cost tracking)
- Private endpoint connectivity health

## References
- [Azure Storage Security Guide](https://learn.microsoft.com/en-us/azure/storage/common/security-recommendations)
- [Storage Encryption](https://learn.microsoft.com/en-us/azure/storage/common/storage-service-encryption)
- [Private Endpoints for Storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints)
- [Defender for Storage](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-storage-introduction)
