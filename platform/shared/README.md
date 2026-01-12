# Platform Shared Contract

This directory contains shared contracts and conventions used across all platform modules to ensure consistency and prevent divergence.

## Purpose

The shared contract establishes:
- **Standard Parameters**: Consistent parameter names, types, and defaults across all platform modules
- **Naming Conventions**: Standardized resource naming patterns
- **Output Standards**: Consistent output names for shared platform resources

## Files

### `contract.bicep`
Documentation of standard parameters that all platform modules should use:
- `environment` (string, default: 'prod')
- `location` (string)
- `tags` (object)
- `logAnalyticsWorkspaceResourceId` (string, default: '')

### `naming.bicep`
Helper functions and conventions for resource naming following the standard pattern:
- Pattern: `<org>-<env>-<region>-<domain>-<resource>-<purpose>-<nn>`
- Region code mapping (e.g., `australiaeast` → `aue`)
- Resource type abbreviations
- Naming helper functions

## Standard Parameters

All platform modules should include these standard parameters:

```bicep
@description('Deployment environment')
param environment string = 'prod'

@description('Azure region for resource deployment')
param location string

@description('Tags to apply to all resources')
param tags object

@description('Log Analytics Workspace resource ID for diagnostics')
param logAnalyticsWorkspaceResourceId string = ''
```

## Standard Outputs

Modules that create shared platform resources should output using these standard names:

| Output Name | Description | Module |
|------------|-------------|--------|
| `logAnalyticsWorkspaceResourceId` | Log Analytics Workspace resource ID | `la-workspace.bicep` |
| `virtualHubResourceId` | Virtual Hub resource ID | `vwan-hub.bicep` |
| `azureFirewallResourceId` | Azure Firewall resource ID | `vwan-hub.bicep` |
| `virtualWanResourceId` | Virtual WAN resource ID | `vwan-hub.bicep` |

## Naming Conventions

### Pattern
```
<org>-<env>-<region>-<domain>-<resource>-<purpose>-<nn>
```

### Components
- **org**: Organization prefix (e.g., `rai`)
- **env**: Environment (e.g., `prod`, `nonprod`)
- **region**: Region short code (e.g., `aue` for Australia East, `ause` for Australia Southeast)
- **domain**: Domain/workload type (e.g., `corp`, `online`, `platform`, `ingress`, `shared`)
- **resource**: Resource type abbreviation (e.g., `vnet`, `kv`, `agw`)
- **purpose**: Purpose or application (e.g., `lending`, `identity`, `connectivity`)
- **nn**: Sequential number (e.g., `01`, `02`)

### Examples

#### Virtual Networks
- Workload spoke VNet (corp): `vnet-rai-prod-aue-corp-01`
- Workload spoke VNet (online): `vnet-rai-prod-aue-online-01`
- Ingress spoke VNet: `vnet-rai-prod-aue-ingress-01`
- Shared services spoke: `vnet-rai-prod-aue-shared-01`

#### Subnets (Contextual - within VNet)
- Workload: `snet-workload`
- Private endpoints: `snet-private-endpoints` (or `snet-pe`)
- App Gateway: `snet-appgw`
- Integration: `snet-integration`
- Management: `snet-mgmt`

#### Network Security Groups & Route Tables (Contextual)
- NSG for workload: `nsg-workload`
- NSG for integration: `nsg-integration`
- Route table for egress: `rt-spoke-egress`

#### Private DNS Zones
- Resource name: `pdns-rai-prod-aue-privatelink-vaultcore-01`
- Zone name: Remains the actual DNS zone name (e.g., `privatelink.vaultcore.azure.net`)

#### Key Vault
- Platform: `kv-rai-prod-aue-platform-01`
- Workload: `kv-rai-prod-aue-lending-01`

#### Application Gateway
- App Gateway: `agw-rai-prod-aue-ingress-01`
- Public IP: `pip-rai-prod-aue-agw-ingress-01`
- WAF Policy: `wafp-rai-prod-aue-agw-ingress-01`

#### Log Analytics Workspace
- Platform: `law-rai-prod-aue-platform-01`
- Workload: `law-rai-prod-aue-lending-01`

#### Virtual WAN & Hub
- Virtual WAN: `vwan-rai-prod-aue-01`
- Virtual Hub: `vhub-rai-prod-aue-01`
- Azure Firewall: `fw-rai-prod-aue-hub-01`

### Region Short Codes

| Full Region Name | Short Code |
|-----------------|------------|
| `australiaeast` | `aue` |
| `australiasoutheast` | `ause` |
| `australiacentral` | `auc` |
| `australiacentral2` | `auc2` |

### Resource Type Abbreviations

| Resource Type | Abbreviation |
|--------------|-------------|
| Virtual Network | `vnet` |
| Subnet | `snet` |
| Network Security Group | `nsg` |
| Route Table | `rt` |
| Private DNS Zone | `pdns` |
| Key Vault | `kv` |
| Application Gateway | `agw` |
| Public IP | `pip` |
| WAF Policy | `wafp` |
| Log Analytics Workspace | `law` |
| Virtual WAN | `vwan` |
| Virtual Hub | `vhub` |
| Azure Firewall | `fw` |

## Usage in Modules

### Including Standard Parameters

```bicep
@description('Deployment environment')
param environment string = 'prod'

@description('Azure region for resource deployment')
param location string

@description('Tags to apply to all resources')
param tags object

@description('Log Analytics Workspace resource ID for diagnostics')
param logAnalyticsWorkspaceResourceId string = ''
```

### Using Naming Conventions

Reference the naming patterns and examples above when creating resource names in your modules. For Bicep functions, you can use helper functions from `naming.bicep` (when importing as a module) or implement the pattern inline.

Example:
```bicep
var regionCode = 'aue' // or use helper function to derive from location
var vnetName = 'vnet-rai-prod-${regionCode}-corp-01'
```

## Benefits

1. **Consistency**: All modules use the same parameter names and types
2. **Discoverability**: Resource names immediately identify purpose, environment, and location
3. **Maintainability**: Changes to standards only require updates in one place (documentation)
4. **Automation**: Standardized outputs enable reliable resource discovery in scripts
5. **Governance**: Naming conventions support policy enforcement and resource organization
