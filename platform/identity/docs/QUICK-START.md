# Identity Pipeline - Quick Start Guide

This guide provides quick reference commands and workflows for managing the Identity & Access Baseline system. For detailed architecture and design decisions, see the [Identity System Review](IDENTITY-SYSTEM-REVIEW.md).

## Running the Pipeline

### Full Pipeline

The recommended approach is to run the complete pipeline, which validates configuration, generates role assignments, syncs AAD groups, and prepares deployment parameters.

```powershell
cd platform/identity/scripts
.\invoke-capability-access-pipeline.ps1
```

To process specific projects only:

```powershell
.\invoke-capability-access-pipeline.ps1 -Projects "fraud-engine"
.\invoke-capability-access-pipeline.ps1 -Projects "fraud-engine,lending-core"
```

### Pipeline Steps

The pipeline executes the following steps in sequence:

1. Validates role mapping file (checks for duplicate role definitions)
2. Generates role assignments from capability and project configurations
3. Syncs AAD groups (creates or finds groups in Azure AD and updates mappings)
4. Generates Bicep parameter files for deployment

## Common Workflows

### Adding a New Role to a Capability

When you need to add a new Azure RBAC role to an existing capability:

1. Edit the capability YAML file (e.g., `config/capabilities/compute.yaml`):
   ```yaml
   capability: compute
   accessLevels:
     contributor:
       - Virtual Machine Contributor
       - New Role Name
   ```

2. Fetch the role definition GUID from Azure:
   ```bash
   az role definition list --name "New Role Name" --query "[0].name" -o tsv
   ```

3. Add the role to `bicep/role-definition-ids.json`:
   ```json
   {
     "New Role Name": "guid-from-step-2"
   }
   ```

4. Run the pipeline to regenerate assignments:
   ```powershell
   .\invoke-capability-access-pipeline.ps1
   ```

### Adding a New Project

To onboard a new project into the identity system:

1. Create a new project YAML file at `config/projects/new-project.yaml`:
   ```yaml
   project: new-project
   
   environments:
     dev:
       scope: resourceGroup
       subscriptionId: <subscription-guid>
       resourceGroup: new-project-dev-rg
       capabilities:
         compute:
           - contributor
         security:
           - viewer
         data:
           - viewer
     prd:
       scope: resourceGroup
       subscriptionId: <subscription-guid>
       resourceGroup: new-project-prd-rg
       capabilities:
         compute:
           - contributor
         security:
           - viewer
   ```

2. Run the pipeline. It will automatically detect and process the new project:
   ```powershell
   .\invoke-capability-access-pipeline.ps1
   ```

3. Deploy the role assignments using the deployment script:
   ```powershell
   .\deploy-role-assignments.ps1
   ```

### Deploying Role Assignments

After running the pipeline, deploy the generated role assignments to Azure. The deployment script handles both subscription-scoped and resource group-scoped assignments automatically.

```powershell
cd platform/identity/scripts
.\deploy-role-assignments.ps1
```

The script will:
- Group assignments by scope type (subscription vs resource group)
- Deploy subscription-scoped assignments to each subscription
- Deploy resource group-scoped assignments to each resource group
- Verify resource groups exist before deploying

Alternatively, you can deploy manually using Azure CLI:

```bash
# For subscription-scoped assignments
az account set --subscription <subscription-id>
az deployment sub create \
  --location australiaeast \
  --template-file platform/identity/bicep/role-assignments-subscription.bicep \
  --parameters assignments=@platform/identity/bicep/generated-role-assignments.json \
  --parameters aadGroupIds=@platform/identity/bicep/aad-group-ids.json

# For resource group-scoped assignments
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file platform/identity/bicep/role-assignments-resourcegroup.bicep \
  --parameters assignments=@platform/identity/bicep/generated-role-assignments.json \
  --parameters aadGroupIds=@platform/identity/bicep/aad-group-ids.json \
  --parameters subscriptionId=<subscription-id> \
  --parameters resourceGroupName=<resource-group-name>
```

## Troubleshooting

### Pipeline fails with "duplicate roles"

The validation step checks for duplicate role definitions. If you see this error:

1. Run validation separately to see details:
   ```powershell
   .\validate-role-mapping.ps1
   ```

2. Check `bicep/role-definition-ids.json` for duplicate entries
3. Remove duplicates and ensure each role name maps to a unique GUID

### Deployment fails with "RoleDefinitionDoesNotExist"

This indicates the role GUID is incorrect or the role doesn't exist in the subscription:

1. Verify the role exists and get its GUID:
   ```bash
   az role definition list --name "<Role Name>" --query "[0].name"
   ```

2. Update `bicep/role-definition-ids.json` with the correct GUID
3. Re-run the pipeline and deployment

### Deployment fails with "property 'X' doesn't exist"

This usually means a role name in the generated JSON doesn't match the mapping file:

1. Check capability YAML files for typos in role names
2. Ensure all role names in capabilities exist in `role-definition-ids.json`
3. Re-run the pipeline after fixing

### Resource group does not exist

The deployment script checks for resource group existence before deploying. If a resource group is missing:

1. Create the resource group first, or
2. Remove the environment from the project YAML file if it's not needed yet

## File Locations Reference

| Task | File Location |
|------|---------------|
| Add or edit capabilities | `config/capabilities/*.yaml` |
| Add or edit projects | `config/projects/*.yaml` |
| Add or edit role GUIDs | `bicep/role-definition-ids.json` |
| Run pipeline | `scripts/invoke-capability-access-pipeline.ps1` |
| Deploy assignments | `scripts/deploy-role-assignments.ps1` |
| Subscription template | `bicep/role-assignments-subscription.bicep` |
| Resource group template | `bicep/role-assignments-resourcegroup.bicep` |
| Generated assignments | `bicep/generated-role-assignments.json` |
| Generated parameters | `bicep/aad-group-ids.json` |
| AAD group mapping | `config/aad-group-mapping.json` |

## Prerequisites

Before running the pipeline, ensure you have:

- PowerShell 7 or later installed
- Azure CLI installed and authenticated (`az login`)
- Required PowerShell modules:
  ```powershell
  Install-Module -Name powershell-yaml -Scope CurrentUser
  ```

You also need appropriate Azure permissions:
- User Access Administrator (or Owner) on subscriptions where you're deploying role assignments
- Directory Readers permission in Azure AD to read group information
- Global Administrator or Privileged Role Administrator to create AAD groups (if groups don't exist)
