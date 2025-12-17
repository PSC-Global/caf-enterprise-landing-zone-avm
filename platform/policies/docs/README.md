# Policy Archetype Strategy

This folder implements an archetype-driven policy model to make Azure Security Benchmark (ASB) domains manageable by composing initiatives and assigning them via environment-aware archetypes.

## Quick Start Documentation

- **[POLICY-REFERENCE-GUIDE.md](POLICY-REFERENCE-GUIDE.md)** - For Cloud Engineers: What policies are enforced, what gets blocked, fix examples
- **[ARCHETYPE-GUIDE.md](ARCHETYPE-GUIDE.md)** - Archetype definitions per MG, design decisions, differences between Corp/Online
- **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** - Complete deployment walkthrough, troubleshooting, automation

## Structure
- `definitions/` – One initiative (policy set) per ASB domain (Microsoft built-in policies)
- `archetypes/` – Workload + environment variants (`corp|online|platform` × `prod|nonprod`) with per-initiative parameters
- `assignments/mg/` – Management Group assignment modules per MG
- `assignments/sub/` – Subscription-level archetype assignment module
- `parameters/initiatives/` – Default parameters per initiative
- `scripts/` – Bash deployment scripts
- `docs/` – Comprehensive guides

## Canonical ASB Domain → Initiative
- Asset Management → `asset-management/asset-management-initiative.bicep`
- Backup & Recovery → `backup-recovery/backup-initiative.bicep`
- Compute → `compute/compute-initiative.bicep`
- Data Protection → `data-protection/data-protection-initiative.bicep`
- DevOps → `devops/devops-initiative.bicep`
- Governance → `governance/governance-initiative.bicep`
- Identity → `identity/identity-initiative.bicep`
- Logging & Monitoring → `logging-monitoring/monitoring-initiative.bicep`
- Miscellaneous → `miscellaneous/misc-initiative.bicep`
- Network → `network/network-initiative.bicep`
- Posture & Compliance → `posture-compliance/defender-initiative.bicep`
- Storage → `storage/storage-initiative.bicep`

## Archetypes
Naming: `<workload>-<environment>` (e.g., `corp-prod`, `online-nonprod`, `platform-prod`)

An archetype is parameters only, no policy logic:
```json
{
  "initiatives": {
    "identity-baseline": { "effect": "Deny" },
    "network-baseline": { "effect": "Audit" }
  }
}
```

## Scope Rules
- Tenant Root: none
- `rai` MG: audit-only global guardrails
- Platform MGs: platform archetypes
- Corp/Online MGs: core workload baselines
- Subscription: archetype assignment
- Resource Group: exemptions only

## Example Commands

Deploy an initiative definition:
```bash
az deployment mg create \
  --management-group-id rai \
  --location australiaeast \
  --template-file platform/policies/definitions/identity/identity-initiative.bicep
```

Assign archetype to Corp MG:
```bash
az deployment mg create \
  --management-group-id corp \
  --location australiaeast \
  --template-file platform/policies/assignments/mg/corp.bicep \
  --parameters archetypeName=corp-prod archetype=@platform/policies/archetypes/corp/prod.json
```

Assign archetype to subscription:
```bash
az deployment sub create \
  --location australiaeast \
  --template-file platform/policies/assignments/sub/archetype-assignment.bicep \
  --parameters \
    archetypeName=corp-prod \
    archetype=@platform/policies/archetypes/corp/prod.json \
    subscriptionId=<your-sub-id>
```

## Automation Scripts

All deployment operations can be automated:
```bash
# Deploy all 12 initiatives to tenant root
cd platform/policies/scripts
./deploy-initiative.sh

# Assign archetype to management group
./assign-mg-archetype.sh corp corp-prod ../archetypes/corp/prod.json

# Assign archetype to subscription
./assign-sub-archetype.sh <subscription-id> corp-prod ../archetypes/corp/prod.json
```

## RBAC Boundaries
- Platform SecOps (Tenant/RAI): define initiatives
- Platform Gov (MG): assign archetypes
- Cloud Eng (Subscription): vending only
- App Teams (RG): exemptions
