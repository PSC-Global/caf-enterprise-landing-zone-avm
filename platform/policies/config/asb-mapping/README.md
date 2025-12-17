# Azure Security Benchmark v3 - Control Domain Index

## Overview
This directory contains comprehensive documentation mapping Azure Security Benchmark v3 control families to built-in Azure Policy definitions and implementation guidance for the CAF enterprise landing zone.

## Document Structure

Each domain document includes:
- **Control Mappings**: ASB control IDs mapped to Azure Policy definitions
- **Enforcement Recommendations**: Phased rollout strategy per management group
- **Configuration Examples**: Bicep/JSON templates for secure resource deployment
- **Management Group Guidance**: Specific requirements for each MG in the hierarchy
- **References**: Links to official Microsoft documentation

## Control Domain Documents

### 1. Identity Management
**File:** [identity.md](./identity.md)

**Control Families:**
- Identity Management (IM) - 9 controls
- Privileged Access (PA) - 8 controls
- Account Management (AM) - 5 controls

**Key Controls:**
- IM-2: MFA requirements
- IM-6: Strong authentication controls
- PA-2: Just-in-time access
- PA-7: Least privilege (RBAC)

**Priority:** Critical for Platform Identity MG

---

### 2. Network Security
**File:** [network.md](./network.md)

**Control Families:**
- Network Security (NS) - 10 controls
- Network Perimeter Security (NP) - 4 controls
- Traffic Filtering (TF) - 3 controls

**Key Controls:**
- NS-1: Network segmentation
- NS-2: Private endpoints
- NS-3: Azure Firewall deployment
- NS-8: Block insecure protocols

**Priority:** Critical for Platform Connectivity MG

---

### 3. Data Protection
**File:** [data-protection.md](./data-protection.md)

**Control Families:**
- Data Protection (DP) - 8 controls
- Backup and Recovery (BR) - 4 controls

**Key Controls:**
- DP-3: Encryption in transit (TLS 1.2+)
- DP-4: Encryption at rest
- DP-6: Key Vault key management
- BR-1: Automated backups

**Priority:** High for all MGs

---

### 4. Logging and Monitoring
**File:** [logging-monitoring.md](./logging-monitoring.md)

**Control Families:**
- Logging and Threat Detection (LT) - 7 controls
- Security Operations (SO) - 5 controls

**Key Controls:**
- LT-1: Defender for Cloud
- LT-3: Diagnostic settings
- LT-5: Centralized logging
- SO-3: SIEM/SOAR (Sentinel)

**Priority:** Critical for Platform Management MG

---

### 5. Governance
**File:** [governance.md](./governance.md)

**Control Families:**
- Governance and Strategy (GS) - 10 controls
- Posture and Vulnerability Management (PV) - 7 controls
- Endpoint Security (ES) - 3 controls

**Key Controls:**
- GS-4: Policy governance framework
- GS-7: Resource tagging
- PV-1: Continuous security assessment
- PV-5: Vulnerability scanning

**Priority:** High for Platform Management MG

---

### 6. Compute Security
**File:** [compute.md](./compute.md)

**Control Families:**
- Compute Security (CS) - 8 controls
- Container Security (CO) - 6 controls

**Key Controls:**
- CS-1: Endpoint protection
- CS-7: JIT VM access
- CO-3: Container image scanning
- CO-5: AKS private clusters

**Priority:** High for Landing Zone MGs

---

### 7. Storage Security
**File:** [storage.md](./storage.md)

**Control Families:**
- Storage Security (SS) - 8 controls
- Disk Encryption (DE) - 4 controls

**Key Controls:**
- SS-1: Storage encryption at rest
- SS-2: HTTPS only
- SS-3: Private endpoints
- DE-1: Disk encryption

**Priority:** High for all MGs

---

## Quick Reference Matrix

### Enforcement Priority by Management Group

| Control Domain | Platform Identity | Platform Connectivity | Platform Management | Corp LZ | Online LZ |
|----------------|------------------|----------------------|---------------------|---------|-----------|
| Identity | **Critical** | Medium | Medium | High | High |
| Network | Low | **Critical** | Low | High | High |
| Data Protection | High | Medium | High | **Very High** | High |
| Logging | Medium | Medium | **Critical** | High | High |
| Governance | High | Medium | **Critical** | High | High |
| Compute | Low | Low | Medium | High | High |
| Storage | Medium | Low | High | High | High |

### Phased Enforcement Timeline

#### Phase 1: Foundation (0-30 days) - Audit Mode
- Deploy ASB assignments to all scopes (audit-only)
- Baseline compliance assessment
- Identify critical non-compliant resources
- Plan remediation activities

**Policy Assignments:**
- Tenant Root: ASB v3 (audit)
- All MGs: ASB v3 (audit)

**Critical Enforcements:**
- Platform Connectivity: NS-1, NS-3, NS-8
- Platform Identity: IM-2, IM-6, PA-2, PA-7
- Platform Management: LT-1, LT-3, LT-5

#### Phase 2: Core Security (30-60 days) - Selective Enforcement
- Enforce critical controls in Platform MGs
- Continue audit mode in Landing Zone MGs
- Remediate high-priority findings
- Begin workload team enablement

**Enforcement Updates:**
- Platform MGs: Enforce 80% of controls
- Corp LZ: Enforce critical identity, network controls
- Online LZ: Audit all, plan enforcement

#### Phase 3: Comprehensive Security (60-90 days) - Broad Enforcement
- Enforce most controls in Corp LZ
- Selective enforcement in Online LZ
- Advanced security features (CMK, private endpoints)
- Continuous compliance monitoring

**Enforcement Updates:**
- Platform MGs: 100% enforcement
- Corp LZ: 90% enforcement
- Online LZ: 70% enforcement (internet-facing exemptions)

#### Phase 4: Advanced Security (90+ days) - Full Maturity
- Full enforcement across all landing zones
- Advanced threat protection
- Red team exercises
- Continuous improvement

## Using These Documents

### For Security Architects
1. Review control mappings to understand ASB coverage
2. Identify gaps in current security posture
3. Plan phased enforcement strategy
4. Design exemption processes

### For Platform Engineers
1. Use configuration examples for infrastructure as code
2. Implement Bicep templates from examples
3. Integrate with CI/CD pipelines
4. Monitor policy compliance

### For Workload Teams
1. Review MG-specific guidance for your landing zone
2. Understand non-compliant resources
3. Plan remediation activities
4. Request exemptions where needed

### For Compliance Officers
1. Map ASB controls to regulatory frameworks
2. Generate compliance reports
3. Track remediation progress
4. Audit policy exemptions

## Compliance Mapping

### Regulatory Framework Coverage

| Framework | Primary ASB Domains | Compliance Level |
|-----------|-------------------|------------------|
| **ISO 27001** | All domains | 95%+ |
| **SOC 2 Type II** | Identity, Logging, Governance | 90%+ |
| **PCI DSS v4** | Network, Data Protection, Logging | 85%+ |
| **GDPR** | Data Protection, Privacy, Identity | 90%+ |
| **HIPAA** | Data Protection, Identity, Logging | 85%+ |
| **NIST CSF** | All domains | 90%+ |
| **APRA CPS 234** (Australia) | All domains | 90%+ |

## Exemption Management

### Valid Exemption Scenarios
1. **Technical Limitations**: Service doesn't support control (e.g., legacy PaaS)
2. **Business Requirements**: Valid business case overrides security control
3. **Compensating Controls**: Alternative control provides equivalent security
4. **Planned Remediation**: Exemption with fixed end date during migration

### Exemption Process
1. Workload team submits request with justification
2. Security team reviews and assesses risk
3. Approval by security lead (< 90 days) or CISO (> 90 days)
4. Exemption created in Azure Policy
5. Quarterly review of all exemptions

### Exemption Template
```json
{
  "exemptionName": "corp-lz-vm-public-ip-dev",
  "category": "Waiver",
  "expiresOn": "2025-06-30",
  "displayName": "Development VM requires public IP for testing",
  "description": "Temporary exemption for development VM requiring direct internet access for external API testing. Compensating controls: NSG restricting source IPs, just-in-time access enabled.",
  "policyAssignmentId": "/providers/Microsoft.Management/managementGroups/rai-landing-zones-corp/providers/Microsoft.Authorization/policyAssignments/asb-corp-landing-zones-audit",
  "policyDefinitionReferenceIds": ["NetworkSecurityNoPubIP"]
}
```

## Continuous Improvement

### Monthly Activities
- Review compliance trends
- Update control mappings for new Azure policies
- Assess exemption validity
- Generate executive report

### Quarterly Activities
- Review and update phased enforcement plan
- Conduct security assessment with Defender for Cloud
- Update ASB mappings for new Azure services
- Workload team training on security controls

### Annual Activities
- Full security audit and red team exercise
- Review and update entire policy framework
- Assess alignment with evolving regulatory requirements
- Update exemption processes

## Additional Resources

### Microsoft Documentation
- [Azure Security Benchmark v3](https://learn.microsoft.com/en-us/security/benchmark/azure/)
- [Azure Policy Documentation](https://learn.microsoft.com/en-us/azure/governance/policy/)
- [Cloud Adoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/)
- [Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/)

### Internal Resources
- Policy Deployment Scripts: `../scripts/`
- Parameter Files: `../parameters/`
- Compliance Reports: `../../generated/`
- Platform Documentation: `../../../docs/`

### Support Contacts
- **Security Team**: security@organization.com
- **Platform Team**: platform@organization.com
- **Compliance Team**: compliance@organization.com

---

**Document Version:** 1.0.0  
**Last Updated:** 12 December 2025  
**Maintained By:** CAF Enterprise Landing Zone Security Team  
**Review Cycle:** Quarterly
