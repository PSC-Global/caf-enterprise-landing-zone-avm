# Identity Pipeline - Quick Start Guide

## 🚀 Running the Pipeline

### Full Pipeline (Recommended)

```powershell
cd platform/identity/scripts
.\invoke-capability-access-pipeline.ps1
```

**For specific projects:**
```powershell
.\invoke-capability-access-pipeline.ps1 -Projects "fraud-engine"
.\invoke-capability-access-pipeline.ps1 -Projects "fraud-engine,lending-core"
```

### What the Pipeline Does

1. ✅ **Validates** role mapping file (checks for duplicates)
2. ✅ **Generates** role assignments from capability + project configs
3. ✅ **Syncs** AAD groups (creates/finds groups in Azure AD based on project YAML)
4. ✅ **Generates** Bicep parameter files for deployment

### Deploy RBAC Assignments

After running the pipeline, deploy the RBAC assignments:

```powershell
cd platform/identity/scripts
.\deploy-role-assignments.ps1
```

---

## 📝 Typical Workflow

### 1. Add a New Role to a Capability

```yaml
# Edit: config/capabilities/compute.yaml
capability: compute
accessLevels:
  contributor:
    - Virtual Machine Contributor
    - New Role Name  # ← Add here
```

Then:
1. Fetch the role GUID:
   ```bash
   az role definition list --name "New Role Name" --query "[0].name" -o tsv
   ```
2. Add to `bicep/role-definition-ids.json`:
   ```json
   {
     "New Role Name": "guid-from-step-1"
   }
   ```
3. Run pipeline to regenerate assignments

### 2. Add a New Project

1. Create `config/projects/new-project.yaml`:
   ```yaml
   project: new-project
   environments:
     dev:
       scope: resourceGroup
       subscriptionId: <guid>
       resourceGroup: new-project-dev-rg
       capabilities:
         compute:
           - contributor
         data:
           - viewer
     prd:
       scope: resourceGroup
       subscriptionId: <guid>
       resourceGroup: new-project-prd-rg
       capabilities:
         compute:
           - contributor
         data:
           - viewer
   ```
2. Run pipeline (it will pick up new project automatically)
   - Groups will be created with naming: `rai-<project>-<env>-<capability>-<level>`
   - Example: `rai-new-project-dev-compute-contributor`
   - **Note:** User membership is managed by IAM (identity) team separately

### 2a. Group Naming Convention

Groups are automatically created based on project YAML configuration with the following naming convention:

**Format:** `rai-<project>-<env>-<capability>-<level>`

**Examples:**
- `rai-lending-core-dev-compute-contributor`
- `rai-lending-core-dev-security-viewer`
- `rai-fraud-engine-prd-ai-contributor`

**Note:** User membership in these groups is managed by the IAM (identity) team separately. The DevOps pipeline only creates the groups and generates RBAC role assignments.

### 3. Deploy RBAC

**Recommended: Use the deployment script**

```powershell
cd platform/identity/scripts
.\deploy-role-assignments.ps1
```

This script automatically:
- Groups assignments by scope (subscription vs resource group)
- Sets the correct subscription for each deployment
- Validates resource groups exist before deploying
- Deploys to all required subscriptions and resource groups

**Alternative: Manual deployment (for specific subscriptions)**

```bash
# Set subscription
az account set --subscription <subscription-id>

# Deploy subscription-scoped assignments
az deployment sub create \
  --location australiaeast \
  --template-file platform/identity/bicep/role-assignments-subscription.bicep \
  --parameters assignments=@platform/identity/bicep/generated-role-assignments.json \
  --parameters aadGroupIds=@platform/identity/bicep/aad-group-ids.json

# Deploy resource group-scoped assignments
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file platform/identity/bicep/role-assignments-resourcegroup.bicep \
  --parameters assignments=@platform/identity/bicep/generated-role-assignments.json \
  --parameters aadGroupIds=@platform/identity/bicep/aad-group-ids.json \
  --parameters subscriptionId=<subscription-id> \
  --parameters resourceGroupName=<resource-group-name>
```

---

## 🔍 Troubleshooting

### Pipeline fails with "duplicate roles"
→ Run validation: `.\validate-role-mapping.ps1`
→ Check `role-definition-ids.json` for duplicate entries

### Deployment fails with "RoleDefinitionDoesNotExist"
→ Role GUID is wrong or role doesn't exist in subscription
→ Verify GUID: `az role definition list --name "<Role Name>" --query "[0].name"`
→ Update `role-definition-ids.json`

### Deployment fails with "property 'X' doesn't exist"
→ Role name in generated JSON doesn't match mapping file
→ Check capability YAML files for typos
→ Re-run pipeline after fixing

### Group naming issues
→ Groups follow the pattern: `rai-<project>-<env>-<capability>-<level>`
→ Verify project YAML has correct project name, environment names, and capabilities
→ Check that capability names match those defined in `config/capabilities/*.yaml`

### User membership
→ User membership is managed by IAM (identity) team separately
→ DevOps pipeline only creates groups and generates RBAC assignments
→ If users are defined in YAML, they will be synced, but this is optional

### Deployment fails with "PrincipalNotFound"
→ Groups don't exist in Entra ID or ObjectIds are stale
→ Re-run the pipeline: `.\invoke-capability-access-pipeline.ps1` to create/update groups
→ Wait 10-30 seconds after group creation for Entra ID replication
→ Verify groups exist: `az ad group list --filter "startswith(displayName,'rai-')"`
→ Check that you're deploying to the correct tenant (ObjectIds are tenant-scoped)

---

## 📂 File Locations

| What You Need | File Location |
|--------------|---------------|
| Add/edit capabilities | `config/capabilities/*.yaml` |
| Add/edit projects | `config/projects/*.yaml` |
| Add/edit role GUIDs | `bicep/role-definition-ids.json` |
| Run pipeline | `scripts/invoke-capability-access-pipeline.ps1` |
| Deploy RBAC | `scripts/deploy-role-assignments.ps1` |
| Deploy templates | `bicep/role-assignments-subscription.bicep`, `bicep/role-assignments-resourcegroup.bicep` |
| Generated assignments | `bicep/generated-role-assignments.json` |
| Generated parameters | `bicep/aad-group-ids.json` |
| Group IDs mapping | `config/aad-group-mapping.json` |
| Group IDs (generated) | `generated/group-ids.json` |

