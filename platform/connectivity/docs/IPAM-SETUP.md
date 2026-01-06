# IPAM Setup Guide

Azure IPAM (IP Address Management) provides centralized management of IP address spaces for your Azure environment.

## Overview

Azure IPAM is deployed as a containerized application in your `platform-management` subscription and provides:

- Centralized CIDR block management
- Automatic IP allocation and tracking
- Subnet planning and visualization
- Integration with Azure Resource Graph for inventory
- REST API for automation

## Deployment Architecture

```
platform-management subscription
└── rg-ipam-prod-australiaeast-001
    ├── Container Instance (IPAM application)
    ├── Cosmos DB (IPAM database)
    ├── App Service (IPAM UI, optional)
    └── Storage Account (IPAM configuration)
```

## Prerequisites

- Platform-management subscription created
- Owner or Contributor permissions on platform-management subscription
- Azure CLI 2.50.0+
- Git installed

## Installation

### 1. Clone IPAM Repository

```bash
git clone https://github.com/Azure/ipam.git
cd ipam
```

### 2. Set Target Subscription

```bash
# List subscriptions
az account list --output table

# Set platform-management subscription
az account set --subscription <platform-management-subscription-id>
```

### 3. Deploy IPAM

#### Option A: Container Instance (Recommended for POC)

```bash
./scripts/deploy.sh \
  --location australiaeast \
  --resource-group rg-ipam-prod-australiaeast-001 \
  --app-name ipam-rai \
  --deployment-type container
```

#### Option B: App Service (Recommended for Production)

```bash
./scripts/deploy.sh \
  --location australiaeast \
  --resource-group rg-ipam-prod-australiaeast-001 \
  --app-name ipam-rai \
  --deployment-type appservice \
  --sku B1
```

### 4. Record Deployment Outputs

```bash
# Get IPAM URL
az deployment group show \
  --resource-group rg-ipam-prod-australiaeast-001 \
  --name ipam-deployment \
  --query properties.outputs.ipamUrl.value -o tsv

# Get API endpoint
az deployment group show \
  --resource-group rg-ipam-prod-australiaeast-001 \
  --name ipam-deployment \
  --query properties.outputs.apiEndpoint.value -o tsv
```

Save these URLs for accessing IPAM portal and API.

## Configuration

### 1. Access IPAM Portal

1. Navigate to IPAM URL from deployment outputs
2. Sign in with Azure AD credentials
3. Accept permissions request

### 2. Configure RBAC

Grant users/groups access to IPAM:

```bash
# Grant IPAM Contributor role to platform team
az role assignment create \
  --role "Contributor" \
  --assignee <platform-team-aad-group-object-id> \
  --scope "/subscriptions/<platform-management-sub-id>/resourceGroups/rg-ipam-prod-australiaeast-001"

# Grant IPAM Reader role to application teams
az role assignment create \
  --role "Reader" \
  --assignee <app-team-aad-group-object-id> \
  --scope "/subscriptions/<platform-management-sub-id>/resourceGroups/rg-ipam-prod-australiaeast-001"
```

### 3. Configure Azure Resource Graph Integration

Enable IPAM to discover existing networks:

1. Go to **Settings** in IPAM portal
2. Enable **Azure Integration**
3. Grant IPAM managed identity `Reader` role at root MG:

```bash
# Get IPAM managed identity object ID
IPAM_IDENTITY=$(az containerapp show \
  --name ipam-rai \
  --resource-group rg-ipam-prod-australiaeast-001 \
  --query identity.principalId -o tsv)

# Grant Reader at root MG
az role assignment create \
  --role "Reader" \
  --assignee $IPAM_IDENTITY \
  --scope "/providers/Microsoft.Management/managementGroups/rai"
```

4. Click **Refresh Inventory** in IPAM portal to discover existing networks

## CIDR Block Configuration

Configure CIDR blocks for subscription vending machine per the enterprise plan.

### 1. Create Address Spaces

In IPAM portal, navigate to **Spaces** and create:

| Space Name | CIDR Block | Region | Purpose |
|------------|------------|--------|---------|
| `rai-hub-aue` | `10.0.0.0/20` | Australia East | vWAN hub |
| `rai-hub-ause` | `10.0.16.0/20` | Australia Southeast | vWAN hub |
| `rai-spokes-aue-prod` | `10.1.0.0/16` | Australia East | Production spokes |
| `rai-spokes-aue-nonprod` | `10.2.0.0/16` | Australia East | Non-production spokes |
| `rai-spokes-ause-prod` | `10.3.0.0/16` | Australia Southeast | Production spokes |
| `rai-spokes-ause-nonprod` | `10.4.0.0/16` | Australia Southeast | Non-production spokes |
| `rai-platform-mgmt` | `10.5.0.0/22` | Australia East | Platform management |
| `rai-platform-identity` | `10.5.4.0/22` | Australia East | Platform identity |
| `rai-platform-logging` | `10.5.8.0/22` | Australia East | Platform logging |

### 2. Create Blocks via Portal

For each space:

1. Click **+ New Space**
2. Enter space name (e.g., `rai-hub-aue`)
3. Enter CIDR block (e.g., `10.0.0.0/20`)
4. Select region: **Australia East** or **Australia Southeast**
5. Add tags:
   - `environment`: `prod` or `nonprod`
   - `purpose`: `hub`, `spoke`, or `platform`
6. Click **Create**

### 3. Create Blocks via API (Optional)

Use IPAM REST API for automation:

```bash
# Get IPAM API URL
IPAM_API_URL=$(az deployment group show \
  --resource-group rg-ipam-prod-australiaeast-001 \
  --name ipam-deployment \
  --query properties.outputs.apiEndpoint.value -o tsv)

# Get access token
TOKEN=$(az account get-access-token --query accessToken -o tsv)

# Create space via API
curl -X POST "${IPAM_API_URL}/api/spaces" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rai-hub-aue",
    "cidr": "10.0.0.0/20",
    "region": "australiaeast",
    "tags": {
      "environment": "prod",
      "purpose": "hub"
    }
  }'
```

### 4. Reserve Hub Blocks

Mark hub blocks as reserved (not for allocation):

1. Navigate to **Spaces** → `rai-hub-aue`
2. Click **Reserve Block**
3. Add description: "vWAN hub Australia East - reserved for platform-connectivity"
4. Repeat for `rai-hub-ause`

### 5. Define Spoke Allocation Policies

Configure automatic allocation rules for spokes:

1. Navigate to **Policies** → **Allocation Policies**
2. Create policy:
   - **Name**: `prod-spoke-allocation`
   - **Space**: `rai-spokes-aue-prod`
   - **Subnet Size**: `/24` (default, adjustable per request)
   - **Auto-assign**: ✅
   - **Require Approval**: ❌ (for automation)
3. Repeat for nonprod spokes

## Integration with Subscription Vending

### Manual CIDR Assignment

1. **For Hub Subscriptions**:
   - Use reserved blocks: `10.0.0.0/23` (AUE), `10.0.16.0/23` (AUSE)
   - Update `subscriptions.json`:
     ```json
     "ipam": {
       "space": "rai-hub-aue",
       "block": "10.0.0.0/23"
     }
     ```

2. **For Spoke Subscriptions**:
   - Request allocation from IPAM portal
   - Record allocated block (e.g., `10.1.5.0/24`)
   - Update `subscriptions.json`:
     ```json
     "ipam": {
       "space": "rai-spokes-aue-prod",
       "block": "10.1.5.0/24"
     }
     ```

### Automated CIDR Assignment (Future Enhancement)

Future enhancement: Create Bicep module to query IPAM API for next available block:

```bicep
// Example future enhancement
module ipamAllocation 'ipam-allocate.bicep' = {
  params: {
    space: 'rai-spokes-aue-prod'
    subnetSize: '/24'
    tags: {
      subscription: subscriptionId
      purpose: 'landing-zone-prod'
    }
  }
}
```

## Subnet Planning

Define subnet blueprints for different spoke types:

### Standard Spoke Blueprint

| Subnet | Purpose | Size | Example CIDR |
|--------|---------|------|--------------|
| `snet-app-001` | Application tier | /26 | 10.1.5.0/26 |
| `snet-data-001` | Database tier | /27 | 10.1.5.64/27 |
| `snet-services-001` | Shared services | /27 | 10.1.5.96/27 |
| `AzureBastionSubnet` | Azure Bastion | /26 | 10.1.5.128/26 |
| Reserved | Future expansion | /26 | 10.1.5.192/26 |

### Configure Subnet Blueprints in IPAM

1. Navigate to **Blueprints** → **+ New Blueprint**
2. Create blueprint:
   - **Name**: `standard-spoke`
   - **Base CIDR Size**: `/24`
   - **Subnets**: (add above subnets)
3. Assign blueprint to space: `rai-spokes-aue-prod`

When creating spoke vNets, reference blueprint:

```json
"ipam": {
  "space": "rai-spokes-aue-prod",
  "block": "10.1.5.0/24",
  "subnetBlueprintKey": "standard-spoke"
}
```

## Operational Tasks

### View IP Utilization

IPAM dashboard shows:
- Total IP space allocated
- Utilization percentage per space
- Available blocks for allocation
- Subnet carving recommendations

### Reclaim Unused IPs

When decommissioning subscriptions:

1. Delete spoke vNet resources in Azure
2. Wait 24 hours for IPAM inventory refresh
3. Navigate to IPAM → **Spaces** → select space
4. Find orphaned block → Click **Release**
5. Block returns to available pool

### Audit IP Assignments

Generate reports:

1. Navigate to **Reports** in IPAM portal
2. Select report type:
   - **Space Utilization**: Shows usage per space
   - **Allocation History**: Tracks all assignments
   - **Orphaned Networks**: Identifies unused blocks
3. Export to CSV for auditing

### Monitor IPAM Health

```bash
# Check IPAM container status
az containerapp show \
  --name ipam-rai \
  --resource-group rg-ipam-prod-australiaeast-001 \
  --query properties.runningStatus

# View logs
az containerapp logs show \
  --name ipam-rai \
  --resource-group rg-ipam-prod-australiaeast-001 \
  --tail 100

# Check Cosmos DB health
az cosmosdb show \
  --name <ipam-cosmosdb-name> \
  --resource-group rg-ipam-prod-australiaeast-001 \
  --query provisioningState
```

## Backup & Recovery

### Backup IPAM Database

Cosmos DB (IPAM database) has automatic backups:

- **Retention**: 30 days (default)
- **Frequency**: Continuous backups every 4 hours
- **Recovery**: Point-in-time restore via Azure Portal

### Manual Export

Export IPAM configuration for disaster recovery:

1. Navigate to IPAM portal → **Settings** → **Export**
2. Download JSON configuration file
3. Store in secure location (e.g., Azure Blob Storage with versioning)

### Restore from Backup

```bash
# Restore Cosmos DB to point-in-time
az cosmosdb sql database restore \
  --account-name <ipam-cosmosdb-name> \
  --resource-group rg-ipam-prod-australiaeast-001 \
  --name ipam-database \
  --restore-timestamp "2024-01-15T10:00:00Z"
```

## Troubleshooting

### IPAM Portal Not Loading

1. Check container app status:
   ```bash
   az containerapp show \
     --name ipam-rai \
     --resource-group rg-ipam-prod-australiaeast-001
   ```

2. Restart container app:
   ```bash
   az containerapp restart \
     --name ipam-rai \
     --resource-group rg-ipam-prod-australiaeast-001
   ```

3. Check DNS resolution:
   ```bash
   nslookup <ipam-url>
   ```

### Azure Integration Not Working

1. Verify managed identity has Reader role at root MG
2. Check Azure Resource Graph query permissions:
   ```bash
   az graph query -q "Resources | where type =~ 'Microsoft.Network/virtualNetworks' | project name, id"
   ```

3. Refresh inventory in IPAM portal → **Settings** → **Azure Integration** → **Refresh**

### CIDR Block Conflicts

If IPAM reports overlap:

1. Check existing networks:
   ```bash
   az network vnet list --query "[].{Name:name, AddressSpace:addressSpace.addressPrefixes}" --output table
   ```

2. Adjust CIDR blocks in IPAM to avoid conflicts
3. Update `subscriptions.json` with corrected blocks

## References

- [Azure IPAM GitHub Repository](https://github.com/Azure/ipam)
- [Azure IPAM Documentation](https://azure.github.io/ipam/)
- [Azure Resource Graph Query Language](https://learn.microsoft.com/azure/governance/resource-graph/concepts/query-language)
- [RFC 1918 Private Address Space](https://datatracker.ietf.org/doc/html/rfc1918)

## Next Steps

- Return to [PREREQUISITES.md](PREREQUISITES.md) to complete other prerequisites
- Proceed to [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for subscription deployment
