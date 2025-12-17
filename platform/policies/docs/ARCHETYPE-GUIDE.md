# Policy Archetype Definitions

This document describes the policy archetypes for each management group in the CAF landing zone hierarchy.

## Archetype Strategy

Each MG has a tailored archetype that applies all 12 ASB domain initiatives with environment-specific strictness:
- **Audit**: Detects non-compliance without blocking
- **Deny**: Prevents non-compliant resources
- **DeployIfNotExists (DINE)**: Auto-remediates configuration gaps
- **Disabled**: Initiative not enforced

## Platform Management Groups

### RAI (Tenant Root)
**Archetype**: `rai/audit-only.json`
- **Purpose**: Global audit-only guardrails
- **Effect**: Audit across all domains
- **Rationale**: Visibility without blocking tenant-wide operations

### Platform-Connectivity
**Archetype**: `platform-connectivity/prod.json`
- **Purpose**: Network and connectivity workloads
- **Key Controls**:
  - Network: **Deny** (strict NSG, DDoS enforcement)
  - Governance: **Deny** (resource standards)
  - Monitoring: **DINE** (auto-enable diagnostics)
- **Rationale**: Network integrity is critical; strict enforcement required

### Platform-Identity
**Archetype**: `platform-identity/prod.json`
- **Purpose**: Identity and access management workloads
- **Key Controls**:
  - Identity: **Deny** (enforce managed identities)
  - Governance: **Deny** (resource standards)
  - Monitoring: **DINE** (auto-enable diagnostics)
- **Rationale**: Identity security is non-negotiable

### Platform-Management
**Archetype**: `platform-management/prod.json`
- **Purpose**: Management and governance workloads
- **Key Controls**:
  - Storage: **Deny** (HTTPS, no public access)
  - Governance: **Deny** (resource standards)
  - Monitoring: **DINE** (auto-enable diagnostics)
- **Rationale**: Management plane requires strict data protection

### Platform-Logging
**Archetype**: `platform-logging/prod.json`
- **Purpose**: Centralized logging and monitoring workloads
- **Key Controls**:
  - Storage: **Deny** (HTTPS, no public access for logs)
  - Governance: **Deny** (resource standards)
  - Monitoring: **DINE** (auto-enable diagnostics)
- **Rationale**: Logging infrastructure must be highly secure

## Landing Zone Management Groups

### Corp-Prod
**Archetype**: `corp/prod.json`
- **Purpose**: Internal corporate production workloads
- **Key Controls**:
  - Identity: **Deny** (enforce managed identities)
  - Network: **Deny** (strict NSG, no public IPs)
  - Storage: **Deny** (HTTPS, no public blob access)
  - Governance: **Deny** (resource standards)
  - Compute: **Deny** (encryption, approved SKUs)
- **Rationale**: Internal workloads require maximum security

### Corp-NonProd
**Archetype**: `corp/nonprod.json`
- **Purpose**: Internal corporate non-production workloads
- **Key Controls**:
  - All domains: **Audit** (visibility without blocking dev/test)
  - Compute: **Audit** (allow broader SKUs for cost optimization)
- **Rationale**: Balance security with development agility

### Online-Prod
**Archetype**: `online/prod.json`
- **Purpose**: Internet-facing production workloads
- **Key Controls**:
  - Identity: **Deny** (enforce managed identities)
  - Network: **Deny** (strict NSG, allow controlled public endpoints)
  - Storage: **Deny** (HTTPS required, selective public access)
  - Governance: **Deny** (resource standards)
  - Compute: **Deny** (encryption, approved SKUs)
- **Rationale**: Public workloads need strict security with controlled internet access

### Online-NonProd
**Archetype**: `online/nonprod.json`
- **Purpose**: Internet-facing non-production workloads
- **Key Controls**:
  - All domains: **Audit** (visibility without blocking dev/test)
- **Rationale**: Balance security with development agility for public-facing apps

## Key Differences: Corp vs Online

| Aspect | Corp | Online |
|--------|------|--------|
| Public Access | **Denied** (no public IPs/endpoints) | **Controlled** (selective public access with HTTPS) |
| Network Posture | **Private-only** | **Hybrid** (private + controlled public) |
| Storage Public Access | **Blocked** entirely | **Conditional** (allow with HTTPS for CDN/static assets) |
| Use Case | Internal apps, databases, file shares | Public websites, APIs, SaaS frontends |

## Deployment Examples

```bash
# Deploy RAI audit-only archetype
az deployment mg create \
  --management-group-id rai \
  --location australiaeast \
  --template-file platform/policies/assignments/mg/rai.bicep \
  --parameters archetypeName=rai-audit archetype=@platform/policies/archetypes/rai/audit-only.json

# Deploy Corp-Prod archetype
az deployment mg create \
  --management-group-id corp \
  --location australiaeast \
  --template-file platform/policies/assignments/mg/corp.bicep \
  --parameters archetypeName=corp-prod archetype=@platform/policies/archetypes/corp/prod.json

# Deploy Online-Prod archetype
az deployment mg create \
  --management-group-id online \
  --location australiaeast \
  --template-file platform/policies/assignments/mg/online.bicep \
  --parameters archetypeName=online-prod archetype=@platform/policies/archetypes/online/prod.json

# Deploy Platform-Connectivity archetype
az deployment mg create \
  --management-group-id platform-connectivity \
  --location australiaeast \
  --template-file platform/policies/assignments/mg/platform-connectivity.bicep \
  --parameters archetypeName=platform-connectivity-prod archetype=@platform/policies/archetypes/platform-connectivity/prod.json
```
