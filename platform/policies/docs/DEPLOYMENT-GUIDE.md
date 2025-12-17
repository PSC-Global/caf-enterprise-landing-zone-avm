# Policy Deployment Guide

Complete walkthrough for deploying the archetype-driven policy framework.

## Prerequisites

1. **Azure CLI**: Version 2.45.0 or higher
2. **RBAC**: Management Group Contributor or Owner at tenant root
3. **Bicep CLI**: Version 0.15.0 or higher (bundled with Azure CLI)
4. **Deployed Initiatives**: All 12 ASB domain initiatives must be deployed first

## Deployment Flow

```
1. Deploy Policy Set Definitions (Initiatives) → Tenant Root
2. Assign Archetypes to Management Groups → Each MG
3. (Optional) Assign Archetypes to Subscriptions → Individual subs
4. Monitor Compliance → Azure Policy dashboard
5. Remediate Non-Compliant Resources → Remediation tasks
```

## Step 1: Deploy Initiative Definitions

**What this does**: Deploys all 12 custom policy initiative definitions (policySetDefinitions) to the `rai` management group—this creates the initiative definitions at tenant MG scope but does NOT assign them to resources yet.

Deploy all 12 ASB domain initiatives to tenant root:

```bash
# Deploy all 12 initiatives to the rai management group
platform/policies/scripts/deploy-initiative.sh rai australiaeast

# Or deploy specific domains only (comma-separated)
platform/policies/scripts/deploy-initiative.sh rai australiaeast identity,compute,network
```

**What happens**:
- Creates 12 custom policy initiative definitions at `/providers/Microsoft.Management/managementGroups/rai`
- Each initiative contains multiple built-in policies grouped by ASB domain
- Initiatives are parameterized with effect controls (Audit/Deny/AuditIfNotExists/Disabled)
- No policies are enforced yet—this only creates the definitions

**Validation via Azure CLI**:
```bash
# Verify all 12 initiatives deployed
az policy set-definition list --management-group rai --query "[?policyType=='Custom'].{Name:name, DisplayName:displayName}" -o table

# View a specific initiative
az policy set-definition show --management-group rai --name identity-baseline
```

**Validation via Azure Portal**:
1. Go to **Azure Portal** → Search "Policy" → **Policy** service
2. Left menu → **Definitions** (under Authoring)
3. Filter: **Type** = "Custom" and **Definition type** = "Initiative"
4. You'll see 12 initiatives:
   - `asset-management-baseline`
   - `backup-baseline`
   - `compute-baseline`
   - `data-protection-baseline`
   - `devops-baseline`
   - `governance-baseline`
   - `identity-baseline`
   - `monitoring-baseline`
   - `misc-baseline`
   - `network-baseline`
   - `defender-baseline`
   - `storage-baseline`
5. Click any initiative → View included policies, parameters (`auditIfNotExistsEffect`, `effect`), and metadata
6. Verify **Scope** shows `/providers/Microsoft.Management/managementGroups/rai`

## Step 2: Assign RAI Audit Archetype

Deploy audit-only archetype to RAI management group:

```bash
# RAI (Tenant Root) - Audit Only
az deployment mg create \
  --management-group-id rai \
  --location australiaeast \
  --name "assign-rai-audit" \
  --template-file platform/policies/assignments/mg/rai.bicep \
  --parameters archetypeName=rai-audit archetype=@platform/policies/archetypes/rai/audit-only.json initiativeMgId=rai
```

## Step 3: Assign Platform Parent MG Archetypes

Deploy archetypes to the **platform** management group (parent scope). These assignments will cascade to all platform-* child MGs:

```bash
# Platform-Connectivity (assigned to platform parent MG)
az deployment mg create \
  --management-group-id platform \
  --location australiaeast \
  --name "assign-platform-connectivity-prod" \
  --template-file platform/policies/assignments/mg/platform-connectivity.bicep \
  --parameters archetypeName=platform-connectivity-prod archetype=@platform/policies/archetypes/platform-connectivity/prod.json initiativeMgId=rai

# Platform-Identity (assigned to platform parent MG)
az deployment mg create \
  --management-group-id platform \
  --location australiaeast \
  --name "assign-platform-identity-prod" \
  --template-file platform/policies/assignments/mg/platform-identity.bicep \
  --parameters archetypeName=platform-identity-prod archetype=@platform/policies/archetypes/platform-identity/prod.json initiativeMgId=rai

# Platform-Management (assigned to platform parent MG)
az deployment mg create \
  --management-group-id platform \
  --location australiaeast \
  --name "assign-platform-management-prod" \
  --template-file platform/policies/assignments/mg/platform-management.bicep \
  --parameters archetypeName=platform-management-prod archetype=@platform/policies/archetypes/platform-management/prod.json initiativeMgId=rai

# Platform-Logging (assigned to platform parent MG)
az deployment mg create \
  --management-group-id platform \
  --location australiaeast \
  --name "assign-platform-logging-prod" \
  --template-file platform/policies/assignments/mg/platform-logging.bicep \
  --parameters archetypeName=platform-logging-prod archetype=@platform/policies/archetypes/platform-logging/prod.json initiativeMgId=rai
```

## Step 4: Assign Landing Zone Archetypes

Deploy archetypes to the **landing-zones** management group (parent scope). These assignments will cascade to both corp and online child MGs:

```bash
# Corp-Prod (assigned to landing-zones parent MG)
az deployment mg create \
  --management-group-id landing-zones \
  --location australiaeast \
  --name "assign-corp-prod" \
  --template-file platform/policies/assignments/mg/corp.bicep \
  --parameters archetypeName=corp-prod archetype=@platform/policies/archetypes/corp/prod.json initiativeMgId=rai

# Corp-NonProd (assigned to landing-zones parent MG)
az deployment mg create \
  --management-group-id landing-zones \
  --location australiaeast \
  --name "assign-corp-nonprod" \
  --template-file platform/policies/assignments/mg/corp.bicep \
  --parameters archetypeName=corp-nonprod archetype=@platform/policies/archetypes/corp/nonprod.json initiativeMgId=rai

# Online-Prod (assigned to landing-zones parent MG)
az deployment mg create \
  --management-group-id landing-zones \
  --location australiaeast \
  --name "assign-online-prod" \
  --template-file platform/policies/assignments/mg/online.bicep \
  --parameters archetypeName=online-prod archetype=@platform/policies/archetypes/online/prod.json initiativeMgId=rai

# Online-NonProd (assigned to landing-zones parent MG)
az deployment mg create \
  --management-group-id landing-zones \
  --location australiaeast \
  --name "assign-online-nonprod" \
  --template-file platform/policies/assignments/mg/online.bicep \
  --parameters archetypeName=online-nonprod archetype=@platform/policies/archetypes/online/nonprod.json initiativeMgId=rai
```

**Policy Inheritance Model:**
Assignments cascade through the hierarchy:
- Policies assigned to **landing-zones** apply to both **corp** and **online** subscriptions
- Policies assigned to **platform** apply to all **platform-\*** subscriptions
- Subscription-scoped assignments override parent MG assignments for that subscription only

## Step 5: (Optional) Subscription-Scoped Assignment

Assign archetype to a specific subscription (overrides MG assignment):

```bash
# Example: Assign corp-prod to a specific subscription
SUBSCRIPTION_ID="12345678-1234-1234-1234-123456789012"

az deployment sub create \
  --location australiaeast \
  --name "assign-sub-corp-prod" \
  --template-file platform/policies/assignments/sub/archetype-assignment.bicep \
  --parameters \
    archetypeName=corp-prod \
    archetype=@platform/policies/archetypes/corp/prod.json \
    subscriptionId=$SUBSCRIPTION_ID \
    initiativeMgId=rai
```

## Step 6: Monitor Compliance

Check compliance status across all assignments:

**Via Azure CLI**:
```bash
# View compliance summary
az policy state summarize \
  --management-group rai \
  --query "policyAssignments[].{Assignment:name, NonCompliant:results.nonCompliantResources}" \
  -o table

# View non-compliant resources for specific assignment
az policy state list \
  --scope "/providers/Microsoft.Management/managementGroups/corp" \
  --filter "policyAssignmentName eq 'corp-prod-identit'" \
  --query "[?complianceState=='NonCompliant'].{Resource:resourceId, Policy:policyDefinitionName}" \
  -o table
```

**Via Azure Portal**:
1. Go to **Azure Portal** → **Policy** → **Compliance**
2. Filter by **Scope** (select your management group or subscription)
3. View compliance state by:
   - **Policy assignments**: Shows each archetype assignment (e.g., `corp-prod-identity-initiative`)
   - **Resources**: Lists compliant/non-compliant resources
   - **Policies**: Individual policy compliance within initiatives
4. Click any assignment → **View compliance details** → See non-compliant resources and specific policy violations
5. Export compliance data using **Download** button (CSV/JSON) for reporting

## Step 7: Remediate Non-Compliant Resources

Create remediation tasks for DeployIfNotExists policies:

```bash
# Example: Remediate monitoring initiative in platform-logging MG
az policy remediation create \
  --management-group-id platform-logging \
  --name "remediate-monitoring-dine" \
  --policy-assignment "platform-logging-prod-monitoring-initiative"

# Check remediation status
az policy remediation show \
  --management-group-id platform-logging \
  --name "remediate-monitoring-dine"
```

## Automation Scripts

Use provided scripts for bulk operations:

```bash
# Deploy all initiatives (Step 1)
cd platform/policies/scripts
./deploy-initiative.sh rai australiaeast

# Or deploy specific domains only
./deploy-initiative.sh rai australiaeast identity,compute,network

# Clean up for end-to-end testing
./delete-assignments.sh
```

**Future Enhancement:** Wrapper script to automate all assignment deployments (Steps 2-4) across all archetypes.

## Troubleshooting

### Issue: "Policy assignment failed with AuthorizationFailed"
**Solution**: Ensure you have Management Group Contributor role at target MG:
```bash
az role assignment create \
  --role "Resource Policy Contributor" \
  --assignee <user-object-id> \
  --scope /providers/Microsoft.Management/managementGroups/<mg-id>
```

### Issue: "Initiative definition not found"
**Solution**: Verify initiative deployed at the `rai` management group (where initiative definitions live):
```bash
# Check if initiatives exist at rai scope
az policy set-definition show \
  --management-group rai \
  --name identity-baseline

# List all 12 initiatives at rai
az policy set-definition list \
  --management-group rai \
  --query "[?policyType=='Custom'].name" \
  -o table
```

**Architecture Note:** All initiative **definitions** must be at the `rai` management group. When assigning to other MGs (landing-zones, platform), use the `initiativeMgId=rai` parameter to reference definitions at rai scope.

### Issue: "Compliance data not showing"
**Solution**: Wait 15-30 minutes for initial policy scan, then trigger manual scan:
```bash
az policy state trigger-scan --resource-group <rg-name>
```

### Issue: "Managed identity creation failed"
**Solution**: Ensure deployment location supports system-assigned identities:
```bash
# Use australiaeast or another primary region
az deployment mg create --location australiaeast ...
```

## Best Practices

1. **Always deploy initiatives first**: Assign all archetypes AFTER initiatives exist at rai scope
2. **Deploy to parent MGs**: Assign archetypes to landing-zones (for corp/online) and platform (for platform-*) so policies cascade to child MGs
3. **Test in nonprod first**: Validate archetypes in corp-nonprod and platform-* prod before enforcing on corp-prod
4. **Use Audit initially**: Deploy all assignments as Audit first (via archetype effect parameter), monitor for 2 weeks, then switch to Deny
5. **Use initiativeMgId parameter**: When deploying assignments outside rai, always set `initiativeMgId=rai` to reference initiatives at rai scope
6. **Document exemptions**: Use Azure Policy exemptions with expiration dates and business justification
7. **Version control archetypes**: Treat archetype JSONs as config-as-code; use Git tags for releases
8. **Monitor remediation tasks**: DeployIfNotExists policies create background tasks; monitor for failures
9. **Review monthly**: Schedule monthly compliance reviews; update archetypes as needed

## Rollback Procedure

If an archetype causes issues:

```bash
# Option 1: Delete a specific assignment at landing-zones scope
az policy assignment delete \
  --name "corp-prod-identity-bas" \
  --management-group landing-zones

# Option 2: Delete an assignment at platform scope
az policy assignment delete \
  --name "platform-logging-prod-moni" \
  --management-group platform

# Option 3: Clean up all assignments and initiatives for testing
cd platform/policies/scripts
./delete-assignments.sh

# Then redeploy with corrected archetypes
```

## Maintenance

- **Quarterly**: Review Microsoft built-in policy updates; refresh initiative definitions
- **Monthly**: Analyze compliance trends; adjust archetype effects as needed
- **Weekly**: Check remediation task status; resolve failed tasks
- **Daily**: Monitor new non-compliant resources; investigate root causes
