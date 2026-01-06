# Deployment Guide

Step-by-step guide for deploying subscriptions using the subscription vending machine.

## Pre-Deployment Checklist

Before starting, ensure you have completed all items in [PREREQUISITES.md](PREREQUISITES.md):

- [ ] MCA billing scope ID obtained
- [ ] Azure permissions configured (Owner at root MG, Subscription Creator on billing)
- [ ] Resource providers registered
- [ ] Management group hierarchy created
- [ ] Azure CLI 2.50.0+ and PowerShell 7.0+ installed
- [ ] AAD groups created for RBAC
- [ ] Policy definitions deployed
- [ ] Configuration file `subscriptions.json` updated with billing scope

## Deployment Workflow

The subscription vending process consists of two phases:

1. **Phase 1**: Create subscription alias and associate with management group
2. **Phase 2**: Bootstrap subscription with resource groups, diagnostics, and governance

## Phase 0: Configuration

### 1. Review Existing Configuration

```bash
cd subscription-vending
cat config/subscriptions.json
```

### 2. Add New Subscription

Edit `config/subscriptions.json` and add new subscription entry:

```json
{
  "aliasName": "rai-corp-app-001",
  "displayName": "rai-corp-app-001",
  "billingScope": "/providers/Microsoft.Billing/billingAccounts/<id>/billingProfiles/<id>/invoiceSections/<id>",
  "targetMg": "corp",
  "role": "spoke",
  "primaryRegion": "australiaeast",
  "ownerAadGroup": "Corp-Owners",
  "archetype": "corp",
  "tags": {
    "costCenter": "CC-APP-001"
  },
  "drSubscription": {
    "enabled": true,
    "primaryRegion": "australiasoutheast",
    "drMode": "active-passive"
  }
}
```

## Phase 1: Create Subscription & Associate with MG

### 1. Run Deployment Script

```powershell
cd subscription-vending/scripts

# Dry run (WhatIf mode)
./deploy-mg-alias.ps1 -SubscriptionId "rai-corp-app-001" -WhatIf

# Actual deployment
./deploy-mg-alias.ps1 -SubscriptionId "rai-corp-app-001"
```

**Expected Output**:
```
[2024-01-15 10:00:00] [INFO] Loading configuration from ../config/subscriptions.json
[2024-01-15 10:00:01] [INFO] Found subscription: rai-corp-app-001
[2024-01-15 10:00:01] [INFO] Target MG: corp
[2024-01-15 10:00:01] [SUCCESS] Phase 1: Creating subscription alias at tenant scope
[2024-01-15 10:02:15] [SUCCESS] Subscription created: a1b2c3d4-e5f6-7890-abcd-1234567890ab
[2024-01-15 10:02:15] [SUCCESS] Phase 2: Associating subscription with management group
[2024-01-15 10:02:30] [SUCCESS] Subscription associated with MG: corp
[2024-01-15 10:02:30] [SUCCESS] Phase 3: Creating DR subscription
[2024-01-15 10:02:45] [SUCCESS] DR subscription created: b2c3d4e5-f6a7-8901-bcde-2345678901bc
[2024-01-15 10:02:50] [SUCCESS] Subscription deployment completed successfully
```

### 2. Verify Subscription Creation

```bash
# Verify subscription exists (using alias)
az account subscription alias show --name "rai-corp-app-001"

# Get subscription ID from alias
SUB_ID=$(az account subscription alias show \
  --name "rai-corp-app-001" \
  --query "properties.subscriptionId" -o tsv)

echo "Subscription ID: $SUB_ID"

# Verify MG association
az account management-group subscription show \
  --name corp \
  --subscription $SUB_ID
```

## Phase 2: Bootstrap Subscription

### 1. Run Bootstrap Script

```powershell
cd subscription-vending/scripts

# Dry run (WhatIf mode)
./deploy-subscription.ps1 -SubscriptionId "corp-app-001" -WhatIf

# Actual deployment
./deploy-subscription.ps1 -SubscriptionId "corp-app-001"
```

**Expected Output**:
```
[2024-01-15 10:05:00] [INFO] Loading configuration from ../config/subscriptions.json
[2024-01-15 10:05:01] [INFO] Bootstrapping subscription: rai-corp-app-001
[2024-01-15 10:05:01] [INFO] Role: spoke
[2024-01-15 10:05:01] [INFO] Resolved Azure Subscription ID: a1b2c3d4-e5f6-7890-abcd-1234567890ab
[2024-01-15 10:05:01] [SUCCESS] Phase 1: Creating logging resource group
[2024-01-15 10:07:30] [SUCCESS] Logging resource group created: rg-workload-logging-australiaeast-001
[2024-01-15 10:07:30] [SUCCESS] Phase 2: Deploying Log Analytics workspace
[2024-01-15 10:09:45] [SUCCESS] Log Analytics workspace deployed
[2024-01-15 10:09:45] [SUCCESS] Phase 3: Deploying diagnostic settings
[2024-01-15 10:10:00] [SUCCESS] Diagnostic settings deployed for subscription
[2024-01-15 10:10:00] [SUCCESS] Phase 4: Applying governance (policies and RBAC)
[2024-01-15 10:12:00] [SUCCESS] Policy archetype applied successfully
[2024-01-15 10:12:30] [SUCCESS] RBAC role assignments applied successfully
[2024-01-15 10:12:30] [SUCCESS] Subscription bootstrap completed successfully
```

### 2. Verify Resource Deployment

```bash
# Set subscription context
az account set --subscription $SUB_ID

# List resource groups
az group list --output table

# Expected RG:
# - rg-<purpose>-logging-australiaeast-001

# Verify Log Analytics workspace
az monitor log-analytics workspace list --output table

# Verify diagnostic settings
az monitor diagnostic-settings subscription list --subscription $SUB_ID --output table

# Verify policy assignments
az policy assignment list --subscription $SUB_ID --output table
```

## Post-Deployment Tasks

### 1. Verify Subscription in Portal

1. Navigate to **Subscriptions** in Azure Portal
2. Find new subscription by display name
3. Verify:
   - ✅ Subscription is in `Enabled` state
   - ✅ Management group is correct
   - ✅ Tags are applied
   - ✅ Resource groups exist
   - ✅ Log Analytics workspace is running

## Next Steps

After successful deployment:

- Review [main README.md](README.md) for operational guidance
- Monitor costs and budgets in Azure Portal
- Review policy compliance regularly
- Document any customizations or deviations from standard
