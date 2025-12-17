# Azure Security Benchmark - Governance Domain Control Mapping

## Overview
This document maps Azure Security Benchmark v3 governance and compliance controls to built-in policy definitions. Use this as a reference for implementing governance, compliance, and operational excellence across the CAF landing zone architecture.

## Control Family: Governance and Strategy (GS)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| GS-1 | Align organization roles, responsibilities, and accountabilities | Define security roles and responsibilities using RBAC | Role assignment monitoring, custom role policies | All MGs: Enforce |
| GS-2 | Define and communicate security strategy | Document and communicate security strategy and standards | Operational (documentation required) | N/A |
| GS-3 | Define and implement a security assurance process | Establish security assessment and validation processes | Defender for Cloud assessments, policy compliance | Platform Management: Enforce |
| GS-4 | Define and implement a security governance framework | Implement governance using Azure Policy and management groups | Management group structure, policy assignments | Platform Management: Enforce |
| GS-5 | Define and implement network segmentation strategy | Implement network segmentation per security requirements | Hub-spoke topology, NSG requirements | Platform Connectivity: Enforce |
| GS-6 | Define and implement identity and privileged access strategy | Implement identity strategy with least privilege | RBAC policies, PIM requirements | Platform Identity: Enforce |
| GS-7 | Define and implement asset management strategy | Track and manage Azure resource inventory | Resource tagging requirements, Azure Resource Graph | All MGs: Enforce |
| GS-8 | Define and implement data protection strategy | Implement data classification and protection controls | Encryption policies, CMK requirements | All MGs: Phase 1 |
| GS-9 | Define and implement incident response strategy | Establish incident response plan and procedures | Azure Sentinel, playbooks | Platform Management: Phase 1 |
| GS-10 | Define and implement backup and recovery strategy | Implement backup strategy for critical resources | Azure Backup policies | All LZ MGs: Enforce |

## Control Family: Posture and Vulnerability Management (PV)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| PV-1 | Discover and remediate security risks | Continuously assess security posture | Microsoft Defender for Cloud | All MGs: Enforce |
| PV-2 | Audit and enforce secure configurations | Implement configuration management and compliance checking | Azure Policy, guest configuration | All MGs: Enforce |
| PV-3 | Define and establish secure configurations | Document and enforce security baselines | Azure Policy initiatives, Bicep templates | All MGs: Enforce |
| PV-4 | Audit and enforce secure configurations for compute resources | Implement OS-level security baselines | Azure Policy guest configuration | All LZ MGs: Phase 1 |
| PV-5 | Perform vulnerability assessments | Scan for vulnerabilities in VMs, containers, databases | Defender for Cloud vulnerability scanning | All LZ MGs: Enforce |
| PV-6 | Rapidly and automatically remediate vulnerabilities | Automate vulnerability remediation where possible | Defender for Cloud auto-remediation | All LZ MGs: Phase 2 |
| PV-7 | Conduct regular red team operations | Perform penetration testing and red team exercises | Operational (not policy-enforced) | Organizational requirement |

## Control Family: Endpoint Security (ES)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| ES-1 | Use Endpoint Detection and Response (EDR) | Deploy Microsoft Defender for Endpoint on all devices | Require Defender for Endpoint | Platform MGs: Enforce, LZ MGs: Phase 1 |
| ES-2 | Use modern anti-malware software | Deploy endpoint protection on all compute resources | Require endpoint protection on VMs | All LZ MGs: Enforce |
| ES-3 | Ensure anti-malware software and signatures are updated | Keep endpoint protection up to date | Monitor endpoint protection health | All LZ MGs: Enforce |

## Phased Enforcement Strategy

### Phase 1: Foundation Governance (Immediate)
- GS-1: RBAC structure
- GS-3: Security assurance (Defender for Cloud)
- GS-4: Policy governance framework
- GS-5: Network segmentation
- GS-6: Identity strategy
- GS-7: Resource tagging
- PV-1: Continuous security assessment
- PV-2: Secure configurations audit
- PV-3: Security baselines
- PV-5: Vulnerability assessments
- ES-2: Anti-malware deployment

### Phase 2: Enhanced Governance (30-60 days)
- GS-8: Data protection strategy
- GS-9: Incident response
- GS-10: Backup strategy
- PV-4: OS-level baselines
- PV-6: Auto-remediation
- ES-1: EDR deployment
- ES-3: Update monitoring

### Phase 3: Advanced Governance (60-90 days)
- PV-7: Red team operations
- GS-2: Strategy documentation complete
- Full governance framework maturity

## Management Group Specific Guidance

### Platform Management
- **Governance Priority**: Critical (governance hub)
- **Requirements**:
  - Central policy management
  - Compliance dashboard
  - Resource inventory and tagging
  - Cost management and optimization
  - Security posture monitoring
  - Backup monitoring and reporting

### Platform Identity
- **Governance Priority**: Critical
- **Requirements**:
  - RBAC role assignment tracking
  - Privileged access governance (PIM)
  - Access review automation
  - Identity risk monitoring
  - Guest user lifecycle management

### Platform Connectivity
- **Governance Priority**: High
- **Requirements**:
  - Network topology governance
  - Connectivity standards enforcement
  - Hub resource inventory
  - Network change tracking

### Corp Landing Zones
- **Governance Priority**: High
- **Requirements**:
  - Tagging enforcement (cost center, owner, environment)
  - Resource naming standards
  - Backup compliance monitoring
  - Security baseline compliance
  - Vulnerability management
  - Configuration drift detection

### Online Landing Zones
- **Governance Priority**: High
- **Requirements**:
  - Tagging enforcement
  - Public-facing resource tracking
  - Security baseline compliance
  - Vulnerability management
  - WAF configuration compliance

## Resource Tagging Strategy

### Required Tags (All Resources)
```json
{
  "Environment": ["Production", "UAT", "Development", "Test"],
  "CostCenter": "CC-XXXX",
  "Owner": "email@domain.com",
  "ApplicationName": "app-name",
  "BusinessUnit": "unit-name",
  "DataClassification": ["Public", "Internal", "Confidential", "HighlyConfidential"]
}
```

### Tag Enforcement
- **Creation Time**: Enforce via policy (deny without tags)
- **Modification**: Track via Activity Log
- **Inheritance**: Resource group tags inherit to resources
- **Exemptions**: Infrastructure resources may have reduced tag requirements

### Tag Governance
```bicep
// Require tags on resource groups
{
  policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025'
  parameters: {
    tagNames: ['Environment', 'CostCenter', 'Owner']
  }
}
```

## Security Baseline Configuration

### Windows Servers
- Windows Security Baseline (Azure Compute Security Baseline)
- Bitlocker enabled on OS and data disks
- Windows Defender enabled and updated
- Windows Update configuration (WSUS or Azure Update Management)
- Local admin password rotation via LAPS

### Linux Servers
- CIS Benchmark for Linux distributions
- SELinux/AppArmor enabled
- Unattended security updates enabled
- SSH hardening (key-based auth, no root login)
- Privileged access monitoring

### Azure PaaS Services
- Minimum TLS 1.2
- Public access disabled (where applicable)
- Diagnostic settings enabled
- Managed identity for authentication
- Private endpoints for connectivity

## Vulnerability Management Process

### Scanning Frequency
- **Production VMs**: Daily
- **Non-Production VMs**: Weekly
- **Container Images**: On build + daily for running containers
- **Databases**: Weekly SQL vulnerability assessment

### Remediation SLAs
- **Critical**: 7 days
- **High**: 30 days
- **Medium**: 90 days
- **Low**: Next maintenance window

### Patching Strategy
- **Production**: Monthly maintenance window + emergency patches
- **Non-Production**: Weekly automated patching
- **Azure PaaS**: Automatic (Microsoft-managed)
- **Testing**: All patches tested in UAT before production

## Compliance Monitoring

### Regulatory Frameworks
- ISO 27001
- SOC 2
- PCI DSS (if applicable)
- GDPR (if applicable)
- APRA CPS 234 (Australia)

### Compliance Dashboard Metrics
- Policy compliance percentage by MG
- Non-compliant resources count and type
- Exempt resources with justification
- Security controls coverage
- Audit log completeness

### Compliance Reporting
- **Frequency**: Monthly executive report, weekly operational report
- **Audience**: CISO, Platform Team, Workload Teams
- **Content**: Compliance trends, exceptions, remediation status
- **Action**: Review exemptions, approve policy updates

## Cost Governance

### Cost Allocation
- Tags used for cost center allocation
- Azure Cost Management + Billing
- Showback/chargeback model per business unit
- Budget alerts at subscription and resource group level

### Cost Optimization Policies
- Unused resources identification (Advisor)
- Right-sizing recommendations
- Reserved instance recommendations
- Spot instance usage for non-critical workloads

### Cost Controls
```bicep
// Deny expensive VM SKUs in non-production
{
  policyDefinitionId: 'allowedVMSKUs'
  parameters: {
    allowedSKUs: ['Standard_B2s', 'Standard_D2s_v3']
  }
  enforcementMode: 'Default'
  scope: 'rg-dev-*'
}
```

## Change Management

### Infrastructure Changes
- All infrastructure as code (Bicep/Terraform)
- Changes via Git pull request
- Peer review required for production
- Automated validation (policy compliance, security scan)
- Deployment via CI/CD pipeline

### Policy Changes
- Proposed changes reviewed by security team
- Impact analysis on existing resources
- Communication to affected workload teams
- Phased rollout (audit → enforce)
- Exemption process for valid business cases

### Exemption Process
1. **Request**: Workload team submits exemption request with business justification
2. **Review**: Security team reviews risk and alternatives
3. **Approval**: Security lead approves with expiration date
4. **Implementation**: Exemption created with scope and duration
5. **Tracking**: Exemptions reviewed quarterly for continued validity

## Resource Naming Convention

### Naming Pattern
```
<resource-type>-<environment>-<region>-<application>-<instance>
```

### Examples
```
vm-prod-aue-fraudengine-01
sql-uat-aue-lendingcore-01
kv-prod-aue-platform-identity
vnet-prod-aue-hub-01
```

### Enforcement
- Policy: Deny resources not matching naming pattern
- Exemptions: Legacy resources during migration
- Validation: Bicep template validation

## References
- [Azure Governance Best Practices](https://learn.microsoft.com/en-us/azure/governance/)
- [Azure Policy Documentation](https://learn.microsoft.com/en-us/azure/governance/policy/)
- [CAF Resource Naming](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Azure Tagging Strategy](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)
