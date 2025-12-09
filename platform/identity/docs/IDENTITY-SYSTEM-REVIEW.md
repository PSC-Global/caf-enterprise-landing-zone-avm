# Identity System Review

This document provides a comprehensive overview of the Identity & Access Baseline system architecture, design decisions, and implementation details. For quick reference commands, see the [Quick Start Guide](QUICK-START.md).

## System Overview

The Identity & Access Baseline implements a capability-based access control model for Azure resources. The system uses Infrastructure-as-Code principles to manage role-based access control (RBAC) assignments through declarative YAML configurations and automated deployment pipelines.

### Core Concepts

**Capabilities** represent functional responsibility boundaries. Each capability maps to a set of related Azure services and defines standard access levels (viewer, operator, contributor, admin) with corresponding Azure RBAC roles.

**Projects** represent business applications or workloads. Each project declares which capabilities it requires and at what access levels, scoped to specific environments (dev, sit, prd).

**Access Levels** provide a standardized permission model:
- Viewer: Read-only access for audit, compliance, and troubleshooting
- Operator: Day-to-day operational access for running services
- Contributor: Resource management and deployment capabilities
- Admin: Full control including access management (typically PIM-eligible)

**Group-Centric Model**: All RBAC assignments are made to Azure AD groups, never to individual users. Groups follow the naming pattern `rai-<capability>-<level>`. Access isolation is achieved through RBAC scope (resource group vs subscription), not through group naming.

## File Structure

### Source Files

#### Configuration Files

```
platform/identity/config/
├── capabilities/
│   ├── ai.yaml
│   ├── compute.yaml
│   ├── data.yaml
│   ├── governance.yaml
│   ├── identity.yaml
│   ├── integration.yaml
│   ├── iot.yaml
│   ├── monitoring.yaml
│   ├── network.yaml
│   ├── security.yaml
│   └── storage.yaml
│
└── projects/
    ├── fraud-engine.yaml
    └── lending-core.yaml
```

Capability files define the role catalog for each capability domain. Project files declare which capabilities are needed for each project's environments.

#### Bicep Templates

```
platform/identity/bicep/
├── role-assignments-subscription.bicep
├── role-assignments-resourcegroup.bicep
└── role-definition-ids.json
```

Two separate Bicep templates handle different scope types:
- `role-assignments-subscription.bicep`: Deploys role assignments at subscription scope
- `role-assignments-resourcegroup.bicep`: Deploys role assignments at resource group scope

The `role-definition-ids.json` file maps Azure RBAC role names to their GUIDs, used by Bicep templates to resolve role definitions.

#### Automation Scripts

```
platform/identity/scripts/
├── invoke-capability-access-pipeline.ps1
├── generate-capability-access.ps1
├── sync-aad-groups.ps1
├── generate-bicepparam.ps1
├── validate-role-mapping.ps1
└── deploy-role-assignments.ps1
```

### Generated Files

These files are created or updated by the pipeline and should be committed to source control for visibility and reproducibility:

```
platform/identity/bicep/
├── generated-role-assignments.json
├── aad-group-ids.bicepparam
└── aad-group-ids.json

platform/identity/config/
└── aad-group-mapping.json
```

## Pipeline Architecture

### High-Level Flow

The system follows a configuration-driven approach:

1. Define capabilities (YAML) - Manual configuration
2. Define projects (YAML) - Manual configuration
3. Run pipeline - Automated processing
4. Deploy RBAC - Automated or manual deployment

### Detailed Pipeline Steps

#### Step 1: Validation

Script: `validate-role-mapping.ps1`

Validates the role definition mapping file for:
- Duplicate role names
- Duplicate GUIDs
- Missing or invalid entries

This step catches configuration errors before processing begins.

#### Step 2: Generate Role Assignments

Script: `generate-capability-access.ps1`

This is the core processing step. The script:

1. Reads all capability YAML files from `config/capabilities/`
2. Reads all project YAML files from `config/projects/`
3. For each project environment:
   - Identifies required capabilities and access levels
   - Looks up corresponding Azure RBAC roles from capability definitions
   - Generates role assignment entries
4. Outputs `generated-role-assignments.json` with entries like:

```json
{
  "project": "fraud-engine",
  "environment": "dev",
  "capability": "compute",
  "level": "contributor",
  "role": "Virtual Machine Contributor",
  "aadGroupName": "rai-compute-contributor",
  "scopeType": "resourceGroup",
  "scopeValue": "99633d42-df6f-4b66-ac1c-94b7ea3d3c8d",
  "resourceGroup": "fraud-engine-dev-rg"
}
```

Key design decisions:
- AAD group names follow `rai-<capability>-<level>` pattern (not project-specific)
- Access isolation is controlled by `scopeType` and `scopeValue`, not group naming
- Each entry represents one role assignment to be created in Azure

#### Step 3: Sync AAD Groups

Script: `sync-aad-groups.ps1`

The script:

1. Scans capability YAML files to determine all required AAD groups
2. For each group following the `rai-<capability>-<level>` pattern:
   - Checks if the group exists in Azure AD
   - Creates the group if it doesn't exist
   - Retrieves the group's object ID
3. Updates `aad-group-mapping.json` with group names and their object IDs

This ensures the system has accurate object IDs for all groups, which are required for RBAC assignments.

#### Step 4: Generate Bicep Parameters

Script: `generate-bicepparam.ps1`

Creates parameter files from the AAD group mapping:
- `aad-group-ids.bicepparam`: Bicep parameter file format
- `aad-group-ids.json`: JSON format for Azure CLI

Both files contain the same data: a mapping of group names to object IDs.

#### Step 5: Deploy Role Assignments

Script: `deploy-role-assignments.ps1`

Deploys role assignments to Azure using Bicep templates. The script:

1. Loads `generated-role-assignments.json`
2. Separates assignments by scope type (subscription vs resource group)
3. For subscription-scoped assignments:
   - Groups by subscription ID
   - Sets Azure context to each subscription
   - Deploys `role-assignments-subscription.bicep`
4. For resource group-scoped assignments:
   - Groups by subscription ID and resource group name
   - Verifies resource groups exist
   - Deploys `role-assignments-resourcegroup.bicep` to each resource group

## Bicep Template Design

### Subscription-Scoped Template

File: `role-assignments-subscription.bicep`

```bicep
targetScope = 'subscription'

param assignments array = []
param aadGroupIds object

var roleDefinitionIds = loadJsonContent('role-definition-ids.json')
var currentSubscriptionId = subscription().subscriptionId
var filteredAssignments = filter(assignments, item => 
  item.scopeType == 'subscription' && 
  item.scopeValue == currentSubscriptionId
)

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = 
  [for assignment in filteredAssignments: {
    name: guid(
      string(assignment.project),
      string(assignment.environment),
      string(assignment.aadGroupName),
      string(assignment.role)
    )
    scope: subscription()
    properties: {
      roleDefinitionId: subscriptionResourceId(
        'Microsoft.Authorization/roleDefinitions',
        roleDefinitionIds[string(assignment.role)]
      )
      principalId: string(aadGroupIds[string(assignment.aadGroupName)])
      principalType: 'Group'
    }
  }]
```

Key features:
- Filters assignments to only those scoped to the current subscription
- Uses deterministic GUIDs for role assignment names (ensures idempotency)
- Resolves role names to GUIDs using the role definition mapping
- Resolves group names to object IDs using the AAD group mapping

### Resource Group-Scoped Template

File: `role-assignments-resourcegroup.bicep`

```bicep
targetScope = 'resourceGroup'

param assignments array = []
param aadGroupIds object
param subscriptionId string
param resourceGroupName string

var roleDefinitionIds = loadJsonContent('role-definition-ids.json')
var filteredAssignments = filter(assignments, item => 
  item.scopeType == 'resourceGroup' && 
  item.scopeValue == subscriptionId && 
  item.resourceGroup == resourceGroupName
)

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = 
  [for assignment in filteredAssignments: {
    name: guid(
      string(assignment.project),
      string(assignment.environment),
      string(assignment.aadGroupName),
      string(assignment.role)
    )
    scope: resourceGroup()
    properties: {
      roleDefinitionId: subscriptionResourceId(
        'Microsoft.Authorization/roleDefinitions',
        roleDefinitionIds[string(assignment.role)]
      )
      principalId: string(aadGroupIds[string(assignment.aadGroupName)])
      principalType: 'Group'
    }
  }]
```

Key features:
- Filters assignments to only those scoped to the specific resource group
- Uses the same deterministic GUID approach for idempotency
- Deploys at resource group scope for fine-grained access control

### Why Two Templates?

Azure treats different scopes differently in deployment templates. Having separate templates allows:
- Using the appropriate `targetScope` for each deployment type
- More efficient filtering of assignments
- Cleaner separation of concerns
- Easier maintenance and troubleshooting

## Project Configuration Format

Projects use an `environments` structure where each environment specifies its scope, subscription, resource groups, and required capabilities:

```yaml
project: fraud-engine

environments:
  dev:
    scope: resourceGroup
    subscriptionId: <subscription-id>
    resourceGroup: fraud-engine-dev-rg
    capabilities:
      compute:
        - contributor
      security:
        - viewer
      ai:
        - contributor
      data:
        - viewer
  prd:
    scope: resourceGroup
    subscriptionId: <subscription-id>
    resourceGroup: fraud-engine-prd-rg
    capabilities:
      compute:
        - contributor
      security:
        - viewer
      ai:
        - contributor
      data:
        - viewer
```

Supported scope types:
- `resourceGroup`: Assignments are scoped to specific resource groups (most common)
- `subscription`: Assignments are scoped to the entire subscription
- `multipleSubscriptions`: Assignments are applied across multiple subscriptions (advanced)

## Design Decisions

### Group Naming Convention

AAD groups follow the pattern: `rai-<capability>-<level>`

Examples:
- `rai-compute-contributor`
- `rai-data-viewer`
- `rai-security-operator`

This design provides:
- Immediate clarity about capability and access level
- Reusability across projects (one group per capability-level combination)
- Simplified group management (fewer groups to maintain)
- Access isolation through RBAC scope, not group naming

### Access Isolation Model

Access isolation is achieved through RBAC scope (resource group vs subscription), not through group naming. A single capability group can be assigned different roles at different scopes across multiple projects. This means:

- One group per capability-level combination (globally reusable)
- Scope determines where access applies (project-specific via resourceGroup assignments)
- No need to create project-specific groups

### Idempotency

All deployments are idempotent. Role assignment names use deterministic GUIDs generated from:
- Project name
- Environment name
- AAD group name
- Role name

This ensures that re-running deployments won't create duplicate assignments. If an assignment already exists, Azure will update it; if it doesn't exist, Azure will create it.

## File Purpose Summary

| File | Type | Purpose | Generated? |
|------|------|---------|------------|
| `config/capabilities/*.yaml` | Source | Defines role catalog per capability | Manual |
| `config/projects/*.yaml` | Source | Defines project capability access | Manual |
| `bicep/role-definition-ids.json` | Source | Maps role names to GUIDs | Manual |
| `bicep/role-assignments-subscription.bicep` | Source | Subscription-scoped RBAC template | Manual |
| `bicep/role-assignments-resourcegroup.bicep` | Source | Resource group-scoped RBAC template | Manual |
| `bicep/generated-role-assignments.json` | Generated | Computed assignments for deployment | Pipeline |
| `bicep/aad-group-ids.bicepparam` | Generated | Bicep parameter file | Pipeline |
| `bicep/aad-group-ids.json` | Generated | JSON parameter for Azure CLI | Pipeline |
| `config/aad-group-mapping.json` | Generated | AAD group name to ObjectId mapping | Pipeline |

## Validation Checklist

Before deploying, verify:

- All capability YAML files are valid YAML syntax
- All project YAML files have correct subscription IDs
- All project YAML files use the `environments` structure (not the deprecated `envs` array)
- Role mapping file has no duplicates (pipeline validates this automatically)
- All role names in capabilities exist in `role-definition-ids.json`
- Pipeline completes without errors
- Generated files are present and contain valid JSON
- Resource groups referenced in project files exist in the target subscriptions

## Key Concepts Summary

### Capability Model

- **Capabilities**: Technical domains (compute, data, security, network, etc.)
- **Projects**: Business applications (fraud-engine, lending-core, etc.)
- **Environments**: Deployment stages (dev, sit, prd)
- **Access Levels**: Permission tiers (viewer, operator, contributor, admin)

### Naming Convention

AAD groups follow: `rai-<capability>-<level>`

This is a global naming pattern. Access isolation is controlled by RBAC scope, not by including project or environment in the group name.

### Scope Model

- **Subscriptions**: Where projects are deployed
- **Resource Groups**: Where environments are deployed (most common scope)
- **RBAC Assignments**: Applied at subscription or resource group scope based on project configuration

## Additional Resources

- [Quick Start Guide](QUICK-START.md) - Quick reference commands and workflows
- [Capability Catalogue](CAPABILITY-CATALOGUE.md) - Detailed reference for all capabilities and their roles
