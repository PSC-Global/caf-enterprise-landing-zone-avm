# Compliance Assignments

This folder contains a lightweight pattern for assigning **regulatory compliance initiatives** (ISO 27001, SOC 2, PCI DSS, etc.) to subscriptions, independent of the main ASB archetype framework.

## Structure

- `assignments/compliance-assignment.bicep`
  - Generic **subscription-scoped** Bicep module that assigns a *single* compliance initiative:
    - `param complianceFramework string` – short name for the framework (e.g. `ISO27001`).
    - `param policySetDefinitionId string` – full resource ID of the built-in regulatory initiative.
    - `param assignmentName string` – assignment name (defaults to `<framework>-compliance`).
    - `param displayName string` – friendly display name for the assignment.
    - `param location string` – region for the managed identity (default `australiaeast`).
    - `param enforcementMode string` – `Default` or `DoNotEnforce` (default is audit-only `DoNotEnforce`).
  - Creates:
    - `Microsoft.Authorization/policyAssignments` with **SystemAssigned** managed identity.
    - `Microsoft.Authorization/roleAssignments` granting **Contributor** to the managed identity (for DeployIfNotExists remediation).

- `configs/*.json`
  - Metadata for common regulatory frameworks, for example:
    - `iso27001.json`
    - `soc2.json`
    - `pcidss.json`
    - `mcsb.json`
    - `ism-protected.json`
  - Each file includes:
    - `framework` – human-readable name.
    - `policySetDefinitionId` – built-in initiative ID.
    - `displayName`, `description` – assignment metadata.
    - `enforcementMode` – usually `DoNotEnforce` for reporting-only.
    - `documentation` – link to Microsoft docs.

## When to use this

Use this module when you want to:

- Attach **regulatory compliance views** to a subscription without changing your ASB-based archetypes.
- Run **audit-only** (DoNotEnforce) initiatives for ISO 27001, SOC 2, PCI DSS, etc.
- Give security/compliance teams a dedicated assignment per framework for dashboards and reporting.

It is intentionally simple and separate from the ASB archetype assignments.

## Basic usage – direct CLI

You can deploy a compliance framework directly by passing parameters to `compliance-assignment.bicep`.

Example: assign **ISO 27001:2013** compliance initiative to a single subscription in audit-only mode:

```bash
SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"

# Switch context
az account set --subscription "$SUBSCRIPTION_ID"

# Deploy ISO 27001 built-in initiative for compliance reporting
az deployment sub create \
  --location australiaeast \
  --name "iso27001-compliance" \
  --template-file platform/policies/compliance/assignments/compliance-assignment.bicep \
  --parameters \
    complianceFramework="ISO27001" \
    policySetDefinitionId="/providers/Microsoft.Authorization/policySetDefinitions/89c6cddc-1c73-4ac1-b19c-54d1a15a42f2" \
    displayName="ISO 27001:2013 Compliance" \
    enforcementMode="DoNotEnforce"
```

Swap the `policySetDefinitionId` and names for other frameworks (see `configs/*.json`).

## Using the config files (optional)

The JSON files under `configs/` are **reference metadata**. You can either:

- Copy values manually from them into your CLI command, or
- Build a small wrapper script (Bash/PowerShell) that:
  - Reads a config file (e.g. `iso27001.json`) using `jq`/PowerShell `ConvertFrom-Json`.
  - Extracts `framework`, `policySetDefinitionId`, `displayName`, `enforcementMode`.
  - Calls `az deployment sub create` with those parameters.

Example Bash pseudo-flow (not included as a script yet):

```bash
FRAMEWORK_CONFIG="platform/policies/compliance/configs/iso27001.json"

FRAMEWORK=$(jq -r .framework "$FRAMEWORK_CONFIG")
PSD_ID=$(jq -r .policySetDefinitionId "$FRAMEWORK_CONFIG")
DISPLAY_NAME=$(jq -r .displayName "$FRAMEWORK_CONFIG")
ENFORCEMENT=$(jq -r .enforcementMode "$FRAMEWORK_CONFIG")

az deployment sub create \
  --location australiaeast \
  --name "iso27001-compliance" \
  --template-file platform/policies/compliance/assignments/compliance-assignment.bicep \
  --parameters \
    complianceFramework="$FRAMEWORK" \
    policySetDefinitionId="$PSD_ID" \
    displayName="$DISPLAY_NAME" \
    enforcementMode="$ENFORCEMENT"
```

## Compliance reporting

Once an assignment is deployed, you can view compliance via Azure Policy:

```bash
# Summarise compliance for a subscription
az policy state summarize \
  --subscription "$SUBSCRIPTION_ID" \
  -o table

# Filter non-compliant resources for this specific assignment
az policy state list \
  --subscription "$SUBSCRIPTION_ID" \
  --filter "policyAssignmentName eq 'iso27001-compliance'" \
  --query "[?complianceState=='NonCompliant'].{Resource:resourceId, Policy:policyDefinitionName}" \
  -o table
```

Alternatively, use the **Azure Portal → Policy → Compliance** blade and filter by the subscription and the compliance assignment name (e.g. `iso27001-compliance`).
