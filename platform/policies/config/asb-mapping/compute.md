# Azure Security Benchmark - Compute Security Domain Control Mapping

## Overview
This document maps Azure Security Benchmark v3 compute security controls to built-in policy definitions for virtual machines, containers, and platform-as-a-service compute resources.

## Control Family: Compute Security (CS)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| CS-1 | Deploy endpoint protection | Install endpoint protection on all compute resources | Require endpoint protection on VMs | All LZ MGs: Enforce |
| CS-2 | Implement secure boot and attestation | Use secure boot and vTPM for Windows/Linux VMs | Require secure boot for generation 2 VMs | Corp LZ: Phase 2, Online LZ: Phase 2 |
| CS-3 | Secure VM and container configurations | Apply security baselines to VMs and containers | Azure Policy guest configuration | All LZ MGs: Phase 1 |
| CS-4 | Manage software updates | Implement automated patch management | Azure Update Management, auto-patching policies | All LZ MGs: Enforce |
| CS-5 | Use approved VM images | Restrict VM creation to approved marketplace images | Allowed VM images policy | All LZ MGs: Enforce |
| CS-6 | Use approved container images | Restrict container deployments to approved registries | Allowed container registries (ACR only) | All LZ MGs: Phase 2 |
| CS-7 | Implement just-in-time VM access | Use Azure Bastion or JIT access for administrative access | Require Azure Bastion, JIT enabled | Platform MGs: Enforce, LZ MGs: Phase 1 |
| CS-8 | Use encrypted connections to VMs | Disable direct RDP/SSH, use encrypted tunnels | Block RDP/SSH from internet, require Bastion | All LZ MGs: Enforce |

## Control Family: Container Security (CO)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| CO-1 | Use managed Kubernetes service | Deploy AKS instead of self-managed Kubernetes | N/A (organizational standard) | All LZ MGs: Standard |
| CO-2 | Secure container registries | Use Azure Container Registry with security scanning | Require ACR, enable Defender for Containers | All LZ MGs: Phase 1 |
| CO-3 | Scan container images for vulnerabilities | Enable vulnerability scanning on container images | Defender for Containers image scanning | All LZ MGs: Enforce |
| CO-4 | Use least privilege for containers | Implement Pod Security Standards in AKS | AKS pod security policies | All LZ MGs: Phase 2 |
| CO-5 | Secure AKS API server access | Restrict API server access with private cluster or authorized IPs | Require AKS private cluster or IP restrictions | Corp LZ: Enforce, Online LZ: Phase 1 |
| CO-6 | Enable AKS monitoring and logging | Send AKS logs to Log Analytics | Require diagnostic settings for AKS | All LZ MGs: Enforce |

## Phased Enforcement Strategy

### Phase 1: Core Compute Security (Immediate)
- CS-1: Endpoint protection
- CS-4: Update management
- CS-5: Approved VM images
- CS-7: JIT access
- CS-8: Encrypted connections
- CO-2: ACR requirement
- CO-3: Container vulnerability scanning
- CO-6: AKS logging

### Phase 2: Enhanced Compute Security (30-60 days)
- CS-2: Secure boot
- CS-3: VM configuration baselines
- CS-6: Container image restrictions
- CO-4: Pod security standards
- CO-5: AKS private cluster

### Phase 3: Advanced Compute Security (60-90 days)
- CO-1: Full AKS adoption
- Advanced threat protection
- Confidential computing adoption

## Management Group Specific Guidance

### Platform Identity
- **Compute Resources**: Minimal (identity services are PaaS)
- **Requirements**:
  - VMs for domain controllers (if hybrid)
  - Secure boot enabled
  - Azure Bastion access
  - Full disk encryption

### Platform Connectivity
- **Compute Resources**: Minimal (network appliances if NVA used)
- **Requirements**:
  - Network virtual appliances (if not using Azure Firewall)
  - Secure boot enabled
  - JIT access
  - Automated patching

### Platform Management
- **Compute Resources**: Management/jump boxes
- **Requirements**:
  - Azure Bastion for access
  - Privileged access workstation (PAW) standards
  - Full disk encryption
  - Enhanced monitoring
  - No public IPs

### Corp Landing Zones
- **Compute Resources**: Enterprise workloads, databases, app servers
- **Requirements**:
  - Approved VM images from corporate gallery
  - Azure Backup enabled
  - Endpoint protection with Defender for Endpoint
  - Azure Update Management
  - Guest configuration policies
  - No RDP/SSH from internet
  - Azure Bastion or VPN for access
  - Private AKS clusters

### Online Landing Zones
- **Compute Resources**: Web apps, APIs, container workloads
- **Requirements**:
  - App Service with private endpoints for backend
  - Container Apps or AKS with network restrictions
  - Vulnerability scanning on all images
  - WAF for public-facing apps
  - Endpoint protection where applicable
  - Auto-scaling and high availability

## Virtual Machine Security Baseline

### Windows Server
```json
{
  "osProfile": {
    "windowsConfiguration": {
      "enableAutomaticUpdates": true,
      "patchSettings": {
        "patchMode": "AutomaticByPlatform"
      }
    }
  },
  "securityProfile": {
    "uefiSettings": {
      "secureBootEnabled": true,
      "vTpmEnabled": true
    },
    "securityType": "TrustedLaunch"
  },
  "storageProfile": {
    "osDisk": {
      "encryptionSettings": {
        "enabled": true
      }
    }
  }
}
```

### Linux Server
```json
{
  "osProfile": {
    "linuxConfiguration": {
      "disablePasswordAuthentication": true,
      "ssh": {
        "publicKeys": [...]
      },
      "patchSettings": {
        "patchMode": "AutomaticByPlatform"
      }
    }
  },
  "securityProfile": {
    "uefiSettings": {
      "secureBootEnabled": true,
      "vTpmEnabled": true
    },
    "securityType": "TrustedLaunch"
  }
}
```

## Container Security Best Practices

### Azure Container Registry (ACR)
- **Network**: Private endpoint, no public access
- **Authentication**: Managed identity for pulls
- **Scanning**: Defender for Containers enabled
- **Retention**: Image cleanup policies
- **Replication**: Geo-replication for HA

### Container Image Standards
```dockerfile
# Use approved base images
FROM mcr.microsoft.com/dotnet/aspnet:8.0

# Run as non-root user
USER app

# Scan for vulnerabilities before deployment
# Vulnerability threshold: Critical = 0, High ≤ 5

# Sign images with Azure Key Vault
# Signature verification in AKS admission controller
```

### AKS Cluster Configuration
```yaml
# Private cluster (API server not exposed to internet)
privateCluster: true

# Azure CNI for network policy support
networkProfile:
  networkPlugin: azure
  networkPolicy: azure

# Managed identity
identity:
  type: SystemAssigned

# Azure AD integration
aadProfile:
  managed: true
  enableAzureRBAC: true

# Monitoring
addonProfiles:
  omsagent:
    enabled: true
    config:
      logAnalyticsWorkspaceResourceID: /subscriptions/.../workspaces/...

# Security
securityProfile:
  defender:
    logAnalyticsWorkspaceResourceId: /subscriptions/.../workspaces/...
    securityMonitoring:
      enabled: true
```

## Approved VM Image Sources

### Corporate Image Gallery
- Windows Server 2022 Datacenter (Azure Edition)
- Ubuntu 22.04 LTS (hardened)
- Red Hat Enterprise Linux 8
- Custom images with security baselines

### Approval Process
1. Base image selected from Azure Marketplace
2. Security baseline applied (CIS, DISA STIG)
3. Corporate tools installed (monitoring, backup agents)
4. Image generalized and captured
5. Security scan passed
6. Published to Shared Image Gallery
7. Version approved by security team

### Update Cycle
- **Frequency**: Monthly
- **Testing**: UAT environment validation
- **Rollout**: Phased (non-prod → prod)
- **Old Versions**: Retained for 90 days

## Patch Management Strategy

### Windows Servers
- **Tool**: Azure Update Management or Azure Automanage
- **Schedule**: 
  - Production: Second Tuesday of month (Patch Tuesday + 7 days)
  - Non-Production: Second Tuesday of month
- **Maintenance Window**: 2-4 hours outside business hours
- **Reboot**: Automatic with coordination

### Linux Servers
- **Tool**: Azure Update Management or unattended-upgrades
- **Schedule**:
  - Production: Weekly security updates, monthly full updates
  - Non-Production: Daily security updates
- **Maintenance Window**: Rolling updates with load balancer drain
- **Reboot**: As needed (kernel updates)

### Container Images
- **Base Image Updates**: Monthly rebuild from latest base
- **Vulnerability Patches**: Immediate rebuild on critical CVE
- **Deployment**: CI/CD pipeline with automated testing
- **Rollback**: Previous image version retained

## Azure Bastion Configuration

### Hub Network Deployment
```bicep
resource bastion 'Microsoft.Network/bastionHosts@2023-04-01' = {
  name: 'bastion-hub-prod-aue'
  location: location
  sku: {
    name: 'Standard'  // Supports native client, IP-based connection
  }
  properties: {
    ipConfigurations: [{
      name: 'bastionIpConfig'
      properties: {
        subnet: {
          id: bastionSubnet.id  // Dedicated subnet /26 or larger
        }
        publicIPAddress: {
          id: bastionPublicIp.id
        }
      }
    }]
    enableTunneling: true
    enableIpConnect: true
    enableShareableLink: false  // Disable for security
  }
}
```

### Access Pattern
1. User authenticates to Azure portal/CLI
2. Connects to VM via Bastion (no public IP on VM)
3. Bastion logs connection to Log Analytics
4. Session recorded for audit

## Endpoint Protection

### Microsoft Defender for Endpoint
- **Coverage**: All Windows and Linux VMs
- **Configuration**: Cloud-delivered protection, automatic sample submission
- **Updates**: Real-time threat intelligence
- **Integration**: Defender for Cloud + Sentinel

### Anti-Malware Extension
```bicep
resource antimalware 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: '${vm.name}/IaaSAntimalware'
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.3'
    settings: {
      AntimalwareEnabled: true
      RealtimeProtectionEnabled: true
      ScheduledScanSettings: {
        isEnabled: true
        day: 7  // Sunday
        time: 120  // 2 AM
        scanType: 'Quick'
      }
      Exclusions: {
        Paths: 'C:\\logs'  // Example: log files
      }
    }
  }
}
```

## Confidential Computing (Advanced)

### DCsv3-series VMs
- Hardware-based encryption (AMD SEV-SNP)
- Memory encryption at runtime
- Use cases: Sensitive data processing, multi-party computation
- Availability: Limited regions

### Trusted Launch (Standard)
- vTPM + Secure Boot
- Boot integrity monitoring
- Available for most VM sizes
- Recommended for all production VMs

## References
- [Azure VM Security Best Practices](https://learn.microsoft.com/en-us/azure/virtual-machines/security-recommendations)
- [AKS Security Best Practices](https://learn.microsoft.com/en-us/azure/aks/concepts-security)
- [Azure Container Registry Security](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-security)
- [Azure Bastion Documentation](https://learn.microsoft.com/en-us/azure/bastion/)
