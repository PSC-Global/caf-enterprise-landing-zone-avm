# Azure Security Benchmark - Logging and Monitoring Domain Control Mapping

## Overview
This document maps Azure Security Benchmark v3 logging and threat detection controls to built-in policy definitions. Use this as a reference for implementing centralized logging, monitoring, and security operations across the CAF landing zone architecture.

## Control Family: Logging and Threat Detection (LT)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| LT-1 | Enable threat detection capabilities | Deploy Microsoft Defender for Cloud across all subscriptions | Enable Defender for Cloud on subscriptions | All MGs: Enforce |
| LT-2 | Enable threat detection for identity and access management | Enable identity protection and sign-in risk detection | Enable Azure AD Identity Protection | Platform Identity: Enforce |
| LT-3 | Enable logging for security investigation | Configure diagnostic settings to send logs to Log Analytics | Require diagnostic settings for all resources | All MGs: Enforce |
| LT-4 | Enable network logging for security investigation | Enable network traffic logging (NSG flow logs, firewall logs) | Enable NSG flow logs, Azure Firewall logs | Platform Connectivity: Enforce, LZ MGs: Phase 1 |
| LT-5 | Centralize security log management and analysis | Aggregate logs to centralized Log Analytics workspace | All logs to central Log Analytics workspace | Platform Management: Enforce, LZ MGs: Enforce |
| LT-6 | Configure log storage retention | Retain logs for required compliance period (typically 90+ days) | Set retention to 90+ days in Log Analytics | Platform Management: Enforce |
| LT-7 | Use approved time synchronization sources | Ensure time sync for accurate log correlation | Azure time synchronization (automatic) | N/A (built-in) |

## Control Family: Security Operations (SO)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| SO-1 | Use a threat intelligence platform | Integrate threat intelligence with security monitoring | Enable Defender for Cloud threat intelligence | Platform Management: Enforce |
| SO-2 | Perform regular security reviews | Conduct security assessments and penetration testing | Defender for Cloud recommendations monitoring | Platform Management: Operational |
| SO-3 | Use security analytics for detection | Implement SIEM/SOAR for security event analysis | Azure Sentinel deployment | Platform Management: Phase 1 |
| SO-4 | Respond to security incidents | Establish incident response procedures and playbooks | Azure Sentinel playbooks, Defender automation | Platform Management: Phase 1 |
| SO-5 | Preserve evidence for investigations | Maintain immutable logs and forensic capabilities | Immutable storage for logs, blob versioning | Platform Management: Enforce |

## Phased Enforcement Strategy

### Phase 1: Core Logging Infrastructure (Immediate)
- LT-1: Defender for Cloud (all subscriptions)
- LT-3: Diagnostic settings (all critical resources)
- LT-4: Network logging (Platform Connectivity)
- LT-5: Centralized Log Analytics (all MGs)
- LT-6: Log retention 90 days minimum
- SO-5: Immutable log storage

### Phase 2: Enhanced Monitoring (30 days)
- LT-2: Identity Protection
- LT-4: Network logging (all LZ MGs)
- SO-1: Threat intelligence integration
- SO-3: Azure Sentinel deployment

### Phase 3: Advanced Security Operations (60-90 days)
- SO-2: Regular security reviews process
- SO-4: Incident response automation
- Custom detection rules and playbooks

## Management Group Specific Guidance

### Platform Management
- **Logging Priority**: Critical (central logging hub)
- **Requirements**:
  - Central Log Analytics workspace (90+ day retention)
  - Azure Sentinel deployment
  - Defender for Cloud centralized management
  - Immutable storage account for long-term log retention (1+ year)
  - Diagnostic settings automation
  - Alert rules for critical security events
  - Integration with ITSM/ticketing system

### Platform Identity
- **Logging Priority**: Critical
- **Requirements**:
  - Azure AD sign-in logs to Log Analytics (immediate)
  - Azure AD audit logs to Log Analytics
  - Identity Protection enabled with alerts
  - Conditional Access policy logs
  - PIM activity logs
  - Key Vault audit logs

### Platform Connectivity
- **Logging Priority**: High
- **Requirements**:
  - NSG flow logs for all NSGs → Log Analytics
  - Azure Firewall logs → Log Analytics
  - VPN Gateway diagnostics → Log Analytics
  - ExpressRoute circuit logs → Log Analytics
  - DDoS protection logs → Log Analytics
  - Traffic Analytics enabled

### Corp Landing Zones
- **Logging Priority**: High
- **Requirements**:
  - All resource diagnostic settings → Log Analytics
  - NSG flow logs for workload subnets
  - Application logs to Log Analytics (VMs, App Services)
  - SQL audit logs to Log Analytics
  - Storage account logging enabled
  - Key Vault logging for secrets access

### Online Landing Zones
- **Logging Priority**: High
- **Requirements**:
  - WAF logs → Log Analytics
  - Application Gateway access/performance logs
  - App Service/Function App logs
  - SQL audit logs with threat detection
  - Storage account logging with threat detection
  - CDN/Front Door logs

## Log Analytics Workspace Design

### Central Platform Workspace
- **Location**: australiaeast
- **Retention**: 90 days (hot), 1+ year (cold tier archive)
- **Access**: Security operations team, platform team
- **Log Sources**:
  - Azure AD logs
  - All subscription activity logs
  - Resource diagnostic logs
  - Network logs (NSG, firewall)
  - Security alerts from Defender for Cloud

### Workspace-per-Landing-Zone (Optional)
- **Use Case**: Data sovereignty, workload team autonomy
- **Retention**: 90 days
- **Access**: Workload team + security operations team
- **Log Sources**: Workload-specific resource logs
- **Note**: Still send critical security logs to central workspace

## Required Diagnostic Settings by Resource Type

### Compute
- **Virtual Machines**: Performance metrics, boot diagnostics
- **App Services**: AppServiceHTTPLogs, AppServiceConsoleLogs, AppServiceAppLogs
- **Function Apps**: FunctionAppLogs, AllMetrics
- **AKS**: kube-apiserver, kube-controller-manager, kube-scheduler

### Network
- **NSGs**: NetworkSecurityGroupEvent, NetworkSecurityGroupRuleCounter, FlowLogs
- **Azure Firewall**: AzureFirewallApplicationRule, AzureFirewallNetworkRule
- **Application Gateway**: ApplicationGatewayAccessLog, ApplicationGatewayPerformanceLog, ApplicationGatewayFirewallLog
- **Load Balancer**: LoadBalancerAlertEvent, LoadBalancerProbeHealthStatus

### Data
- **SQL Database**: SQLInsights, AutomaticTuning, QueryStoreRuntimeStatistics, Errors, DatabaseWaitStatistics, Timeouts, Blocks, Deadlocks
- **Storage Account**: StorageRead, StorageWrite, StorageDelete, Transaction
- **Cosmos DB**: DataPlaneRequests, QueryRuntimeStatistics, PartitionKeyStatistics

### Identity & Security
- **Key Vault**: AuditEvent, AllMetrics
- **Azure AD**: SignInLogs, AuditLogs, NonInteractiveUserSignInLogs, ServicePrincipalSignInLogs
- **Subscription**: Administrative, Security, ServiceHealth, Alert, Recommendation, Policy, Autoscale, ResourceHealth

## Microsoft Defender for Cloud Configuration

### Required Plans by Scope
| Defender Plan | Platform MGs | Corp LZ | Online LZ | Enforcement |
|---------------|-------------|---------|-----------|-------------|
| Servers | ✓ | ✓ | ✓ | Enforce |
| App Service | - | ✓ | ✓ | Enforce |
| SQL Databases | - | ✓ | ✓ | Enforce |
| Storage | ✓ | ✓ | ✓ | Enforce |
| Containers | - | ✓ | ✓ | Phase 1 |
| Key Vault | ✓ | ✓ | ✓ | Enforce |
| Resource Manager | ✓ | ✓ | ✓ | Enforce |
| DNS | ✓ | - | - | Enforce |

### Alert Configuration
- **Critical Alerts**: Email to security operations + SMS
- **High Alerts**: Email to security operations
- **Medium/Low**: Logged to Log Analytics for analysis
- **Integration**: Azure Sentinel for automated response

## Log Retention Policy

### Compliance Requirements
- **General Business**: 90 days (hot) + 1 year (archive)
- **Financial Services**: 7 years
- **Healthcare**: 6 years
- **Government**: Per regulatory body (often 7+ years)

### Implementation
```bicep
// Log Analytics workspace retention
retentionInDays: 90

// Archive to storage account
{
  storageAccountId: '/subscriptions/.../storageAccounts/logarchive'
  retentionPolicy: {
    enabled: true
    days: 2555 // 7 years
  }
  immutabilityPolicy: {
    immutabilityPeriodSinceCreationInDays: 2555
    state: 'Unlocked' // Locked for compliance workloads
  }
}
```

## Security Alerting Rules

### Critical Alerts (Immediate Response)
- Privileged role assignment (Owner, Contributor at tenant/MG level)
- Break-glass account usage
- Azure Firewall rule addition/deletion
- NSG rule allowing internet access to sensitive ports (SQL, RDP, SSH)
- Key Vault secret access from unauthorized IP
- Suspicious sign-in (impossible travel, anonymous IP)
- Malware detected on VM

### High Alerts (1-hour Response)
- Failed MFA attempts (threshold exceeded)
- Resource deployment in unauthorized region
- Public IP assigned to resource in Corp LZ
- Backup failure
- Diagnostic settings disabled
- Encryption disabled on storage/database

### Medium Alerts (24-hour Response)
- Non-compliant resource created
- Unused NSG rule
- Cost anomaly detected
- Certificate expiring within 30 days

## Azure Sentinel Integration

### Data Connectors
- Azure Active Directory
- Azure Activity
- Microsoft Defender for Cloud
- Azure Firewall
- Network Security Groups
- Azure Key Vault
- Office 365 (if applicable)

### Out-of-Box Analytics Rules
- Suspicious sign-in patterns
- Privileged account anomalies
- Network traffic anomalies
- Malware detection
- Data exfiltration indicators

### Custom Playbooks
- Auto-disable compromised user account
- Isolate compromised VM (NSG quarantine)
- Notify security team via Teams/Email
- Create ServiceNow ticket
- Trigger investigation workflow

## Monitoring Dashboards

### Platform Operations Dashboard
- Resource health across all MGs
- Policy compliance status
- Defender for Cloud secure score
- Cost by management group
- Backup success rate

### Security Operations Dashboard
- Active security alerts by severity
- Top attacked resources
- Threat intelligence indicators
- Incident response metrics
- Compliance posture trending

### Network Operations Dashboard
- Azure Firewall traffic patterns
- NSG flow analysis
- DDoS protection events
- ExpressRoute circuit health
- VPN gateway connectivity

## References
- [Azure Monitor Documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/)
- [Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/)
- [Azure Sentinel](https://learn.microsoft.com/en-us/azure/sentinel/)
- [Diagnostic Settings](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/diagnostic-settings)
