# Azure Security Benchmark - Identity Domain Control Mapping

## Overview
This document maps Azure Security Benchmark v3 identity and access management controls to built-in policy definitions. Use this as a reference for understanding ASB identity requirements and planning phased enforcement.

## Control Family: Identity Management (IM)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| IM-1 | Use centralized identity and authentication system | Ensure Azure AD is used as the centralized identity provider for all authentication | Multiple policies enforcing Azure AD authentication | Platform MGs: Enforce, LZ MGs: Phase 2 |
| IM-2 | Protect identity and authentication systems | Implement protections for Azure AD including conditional access and MFA | Require MFA for administrative accounts | Platform Identity: Enforce, All MGs: Phase 1 |
| IM-3 | Manage application identities securely and automatically | Use managed identities for Azure resources instead of service principals | Require managed identities for Azure resources | Platform MGs: Audit, LZ MGs: Phase 3 |
| IM-4 | Authenticate server and services | Use strong authentication methods for server and service authentication | Enforce certificate-based authentication where applicable | Platform MGs: Phase 2, LZ MGs: Phase 3 |
| IM-5 | Use single sign-on (SSO) for application access | Implement SSO for application access through Azure AD | Require SSO integration for enterprise applications | Corp LZ: Phase 2, Online LZ: Phase 3 |
| IM-6 | Use strong authentication controls | Implement strong authentication including passwordless and MFA | Multiple MFA and passwordless policies | All MGs: Enforce (Platform), Audit (LZ) |
| IM-7 | Restrict access based on conditions | Implement conditional access policies for risk-based access control | Require conditional access policies | Platform Identity: Enforce, Corp LZ: Phase 1 |
| IM-8 | Restrict the exposure of credential and secrets | Minimize credential exposure through Key Vault and managed identities | Store secrets in Key Vault, disable local authentication | Platform MGs: Enforce, LZ MGs: Phase 2 |
| IM-9 | Secure user access to existing applications | Ensure secure access patterns for legacy and existing applications | App Proxy policies, VPN gateway requirements | Corp LZ: Phase 2, Online LZ: N/A |

## Control Family: Privileged Access (PA)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| PA-1 | Separate and limit highly privileged users | Implement separation of duties for privileged accounts | Role assignment auditing, custom role limitations | Platform MGs: Enforce, LZ MGs: Audit |
| PA-2 | Avoid standing access for user accounts | Implement just-in-time (JIT) access for privileged operations | Require PIM for privileged roles | Platform Identity: Enforce, All MGs: Phase 1 |
| PA-3 | Manage lifecycle of identities and entitlements | Implement identity lifecycle management and access reviews | Access review policies, guest account restrictions | Platform Identity: Enforce, Corp LZ: Phase 2 |
| PA-4 | Review and reconcile user access regularly | Perform regular access reviews for privileged and standard accounts | Require periodic access reviews | Platform Identity: Enforce, LZ MGs: Phase 2 |
| PA-5 | Set up emergency access | Configure break-glass accounts for emergency access scenarios | Break-glass account monitoring, exclusion policies | Platform Identity: Enforce (monitoring only) |
| PA-6 | Use privileged access workstations | Require PAWs for privileged administrative tasks | Device compliance policies, conditional access | Platform Identity: Phase 2, Platform Management: Phase 2 |
| PA-7 | Follow just enough administration principle | Implement least privilege access using Azure RBAC | Custom role restrictions, deny assignments | All MGs: Enforce |
| PA-8 | Determine access process for cloud provider support | Define Microsoft support access authorization process | Customer Lockbox requirement | Platform MGs: Enforce, LZ MGs: Phase 2 |

## Control Family: Account Management (AM)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| AM-1 | Ensure security team has visibility into risks on tenant | Grant Security Reader access to tenant root for security operations | RBAC assignment monitoring | Platform Identity: Enforce |
| AM-2 | Use only approved services | Restrict service creation to approved Azure services | Allowed resource types policy | Platform MGs: Enforce, LZ MGs: Audit then Phase 1 |
| AM-3 | Use only approved resource providers | Limit registered resource providers to approved list | Resource provider registration restrictions | Platform MGs: Enforce, LZ MGs: Phase 2 |
| AM-4 | Limit access to Azure resources | Implement RBAC restrictions and deny assignments | RBAC best practices, role assignment limits | All MGs: Enforce |
| AM-5 | Use customer-managed keys where supported | Require customer-managed keys for data encryption | Require CMK for storage, SQL, etc. | Platform MGs: Phase 2, Corp LZ: Phase 2 |

## Phased Enforcement Strategy

### Phase 1: Critical Identity Controls (Immediate)
- IM-2: MFA requirements
- IM-6: Strong authentication
- IM-7: Conditional access (Platform Identity only)
- PA-2: JIT access
- PA-7: Least privilege

### Phase 2: Enhanced Identity Security (30-60 days)
- IM-3: Managed identities
- IM-8: Secret management
- PA-3: Lifecycle management
- PA-4: Access reviews
- AM-5: Customer-managed keys

### Phase 3: Comprehensive Identity Governance (90+ days)
- IM-4: Service authentication
- IM-5: SSO requirements
- IM-9: Legacy application security
- PA-6: Privileged access workstations
- AM-3: Resource provider restrictions

## Management Group Specific Guidance

### Platform Identity
- **Enforcement Priority**: Highest
- **Initial Mode**: Enforce (IM-2, IM-6, PA-2, PA-7)
- **Target Compliance**: 100% within 30 days
- **Remediation**: Automated where possible

### Platform Connectivity & Management
- **Enforcement Priority**: High
- **Initial Mode**: Enforce for PA-7, Audit for others
- **Target Compliance**: 95% within 60 days
- **Remediation**: Semi-automated with approvals

### Corp Landing Zones
- **Enforcement Priority**: Medium-High
- **Initial Mode**: Audit all, Phase to Enforce
- **Target Compliance**: 90% within 90 days
- **Remediation**: Workload team responsibility with platform support

### Online Landing Zones
- **Enforcement Priority**: Medium
- **Initial Mode**: Audit all
- **Target Compliance**: 85% within 120 days
- **Remediation**: Workload team responsibility

## References
- [Azure Security Benchmark v3](https://learn.microsoft.com/en-us/security/benchmark/azure/overview)
- [Azure Policy Built-in Definitions](https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies)
- [Azure RBAC Best Practices](https://learn.microsoft.com/en-us/azure/role-based-access-control/best-practices)
