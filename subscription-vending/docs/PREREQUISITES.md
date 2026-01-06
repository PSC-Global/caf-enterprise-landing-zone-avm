# Prerequisites

Complete checklist for subscription vending machine deployment.

## 1. Microsoft Customer Agreement (MCA) Billing

### Requirement
Access to an active Microsoft Customer Agreement with programmatic subscription creation enabled.

### Obtaining Billing Scope ID

1. **Via Azure Portal**:
   - Navigate to **Cost Management + Billing**
   - Select your billing account
   - Go to **Properties**
   - Copy the billing scope ID (format: `/providers/Microsoft.Billing/billingAccounts/<id>/billingProfiles/<id>/invoiceSections/<id>`)

   /providers/Microsoft.Billing/billingAccounts/<billing-account-id>/billingProfiles/<billing-profile-id>/invoiceSections/<invoice-section-id>

2. **Via Azure CLI**:
   ```bash
   # List billing accounts
   az billing account list --output table
   
   # List billing profiles
   az billing profile list --account-name <account-name> --output table
   
   # List invoice sections
   az billing invoice section list \
     --account-name <account-name> \
     --profile-name <profile-name> \
     --output table
   
   # Get billing scope ID
   az billing invoice section show \
     --account-name <account-name> \
     --profile-name <profile-name> \
     --name <invoice-section-name> \
     --query id -o tsv
   ```

3. **Update Configuration**:
   Replace `<your-mca-billing-scope>` in `config/subscriptions.json` with your billing scope ID.

### Permissions Required
- `Subscription Creator` role on the invoice section
- Grant via Azure Portal → Cost Management + Billing → Invoice sections → Access control (IAM)

---

## 2. Azure Permissions

### Management Group Permissions

| Permission | Scope | Required For |
|------------|-------|--------------|
| `Owner` or `Contributor` + `User Access Administrator` | Root MG (`rai`) | Creating subscriptions, assigning to MG |
| `Management Group Contributor` | Root MG | Moving subscriptions between MGs |

**Verify Current Permissions**:
```bash
# Check role assignments at MG
az role assignment list \
  --scope "/providers/Microsoft.Management/managementGroups/rai" \
  --assignee <user-or-sp-object-id> \
  --output table
```

**Grant Permissions** (requires existing Owner):
```bash
# Grant Owner at root MG
az role assignment create \
  --role "Owner" \
  --assignee <user-or-sp-object-id> \
  --scope "/providers/Microsoft.Management/managementGroups/rai"
```

### Subscription Permissions

After subscription creation, the following roles are automatically assigned:
- Creator receives `Owner` role on new subscription

---

## 3. Resource Provider Registration

Register required Azure resource providers at **tenant** level (done once per tenant).

```bash
# Subscription resource provider (for alias creation)
az provider register --namespace Microsoft.Subscription --wait

# Management resource provider (for MG operations)
az provider register --namespace Microsoft.Management --wait

# Networking resource providers
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.Insights --wait
az provider register --namespace Microsoft.Resources --wait

# Verify registration status
az provider show --namespace Microsoft.Subscription --query "registrationState"
az provider show --namespace Microsoft.Management --query "registrationState"
az provider show --namespace Microsoft.Network --query "registrationState"
```

Expected output: `"Registered"`

---

## 4. Management Group Hierarchy

Ensure the following management group structure exists:

```
rai (root)
├── platform
│   ├── platform-management
│   ├── platform-identity
│   └── platform-connectivity
├── landing-zones
│   ├── corp
│   └── online
└── sandbox
```

**Verify Structure**:
```bash
# List all MGs
az account management-group list --output table

# Show specific MG hierarchy
az account management-group show --name rai --expand --recurse
```

**Create Management Groups** (if they don't exist):

Deploy the management group hierarchy using `platform/management/mg-rai.bicep`:

```bash
# Deploy from tenant root scope
az deployment mg create \
  --management-group-id <tenant-root-group-id> \
  --location australiaeast \
  --template-file platform/management/mg-rai.bicep
```

This will create the complete hierarchy including:
- Root MG: `rai`
- Platform MGs: `platform`, `platform-management`, `platform-identity`, `platform-connectivity`
- Landing Zone MGs: `landing-zones`, `corp`, `online`
- Sandbox MG: `sandbox`

---

## 5. Azure Active Directory (AAD) Groups

Create AAD groups for subscription ownership following the naming standards defined in `platform/identity/docs/`.

### Required Groups for Subscription Vending

The following AAD groups are required for subscription ownership (as specified in `ownerAadGroup` field in `subscriptions.json`):

| Group Name | Purpose | Used By |
|------------|---------|---------|
| `Platform-Owners` | Platform management subscription owners | `rai-platform-management-prod-01` |
| `Platform-Identity-Owners` | Platform identity subscription owners | `rai-platform-identity-prod-01` |
| `Platform-Network-Owners` | Platform connectivity subscription owners | `rai-platform-connectivity-prod-01` |
| `Platform-Security-Owners` | Platform logging subscription owners | `rai-platform-logging-prod-01` |
| `Fraud-Owners` | Fraud engine subscription owners | `rai-fraud-engine-prod-01` |
| `Lending-Owners` | Lending core subscription owners | `rai-lending-core-prod-01` |
| `Sandbox-Owners` | Sandbox subscription owners | `rai-sandbox-dev-01` |

**Note**: For workload subscriptions, additional capability-specific groups (e.g., `rai-<project>-<env>-<capability>-<level>`) are created automatically by the identity framework. See `platform/identity/docs/` for details on the complete group naming convention and automation.

**Create Groups**:

Use the identity framework scripts in `platform/identity/scripts/` to create and manage AAD groups according to the standard naming convention.

---

## 6. Azure Policy Definitions

Deploy policy definitions and initiatives before creating subscriptions. The subscription vending machine assigns policy archetypes to subscriptions, which requires the policy framework to be deployed first.

**Deploy Policy Framework**:

Follow the complete deployment guide in `platform/policies/docs/DEPLOYMENT-GUIDE.md`:

1. **Deploy Policy Initiatives** (Step 1):
   ```bash
   # Deploy all 12 ASB domain initiatives to the rai management group
   platform/policies/scripts/deploy-initiative.sh rai australiaeast
   ```

2. **Assign Archetypes to Management Groups** (Step 2):
   ```bash
   # Assign archetypes to platform and landing zone MGs
   platform/policies/scripts/assign-mg-archetype.sh -a platform-management -m platform-management
   platform/policies/scripts/assign-mg-archetype.sh -a online-prod -m online
   # ... etc
   ```

**Verify Policies**:
```bash
# List policy initiatives (sets) at MG scope
az policy set-definition list \
  --management-group rai \
  --query "[?policyType=='Custom'].{Name:name, DisplayName:displayName}" \
  --output table
```

See `platform/policies/docs/DEPLOYMENT-GUIDE.md` for complete deployment instructions and troubleshooting.

---

## Next Steps

Once all prerequisites are met, proceed to [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for deployment instructions.
