# Phase 5 — Private DNS & Private Endpoints: Implementation Summary

## Overview

Phase 5 implements centralized Private DNS zones and a generic Private Endpoint module to ensure no public PaaS access by default.

## Phase 5.1 — Central Private DNS ✅

### Files Created

**`platform/connectivity/bicep/private-dns-zones.bicep`**
- ✅ Creates centralized Private DNS zones for PaaS services
- ✅ Uses AVM `avm/res/network/private-dns-zone:0.7.1`
- ✅ Supports multiple zones configured via `privateDnsZoneConfigs` parameter
- ✅ Zone mapping includes: kv, blob, file, queue, table, dfs, sql, postgresql, mysql, mariadb, redis, servicebus, eventhub, cosmos, appservice, appserviceenvironment
- ✅ Outputs zone resource IDs and names mapped by zone key

**`platform/connectivity/bicep/private-dns-links.bicep`**
- ✅ Links Private DNS zones to Virtual Networks
- ✅ Uses native Bicep (AVM module not available for DNS links)
- ✅ Each VNet explicitly opts into zones it needs (configurable per VNet)
- ✅ Supports auto-registration flag (`registrationEnabled`)
- ✅ Accepts array of zone configurations with zone resource IDs and resource groups

**`platform/connectivity/config/connectivity.prod.json`**
- ✅ Configuration file for connectivity deployment
- ✅ `enablePrivateDns` flag to enable/disable DNS zone deployment
- ✅ `privateDnsZones` array lists which zones to deploy
- ✅ Default includes: kv, blob, file, queue, table, sql, postgresql, mysql

**`platform/connectivity/scripts/deploy-connectivity.ps1`** (Updated)
- ✅ Added `Get-ConnectivityConfig()` function
- ✅ Integrated Private DNS zone deployment for hub subscriptions
- ✅ Deploys DNS zones as separate step (loose coupling from hub module)
- ✅ Retrieves and displays zone resource IDs from deployment outputs

### Deployment Flow

1. **Hub Deployment** (`rai-platform-connectivity-prod-01`)
   ```powershell
   ./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01"
   ```
   - Deploys vWAN hub (Phase 3)
   - Deploys Private DNS zones (Phase 5.1) if `enablePrivateDns: true`
   - DNS zones created in same resource group as hub

2. **VNet Linking** (Configurable per VNet)
   ```powershell
   # Spoke VNet links to zones it needs
   az deployment group create \
     --template-file private-dns-links.bicep \
     --parameters \
       virtualNetworkResourceId="/subscriptions/.../vnet-spoke-001" \
       privateDnsZoneConfigs='[{"zoneResourceId":"/subscriptions/.../privatelink.vaultcore.azure.net","zoneName":"privatelink.vaultcore.azure.net","zoneResourceGroup":"rg-network-..."}]'
   ```

---

## Phase 5.2 — Generic Private Endpoint Module ✅

### File Created

**`workloads/bicep/private-endpoint.bicep`**
- ✅ Generic Private Endpoint module for any PaaS service
- ✅ Uses AVM `avm/res/network/private-endpoint:0.9.0`
- ✅ Parameters:
  - `targetResourceId` - PaaS resource ID (Key Vault, Storage, etc.)
  - `groupIds` - Array of group IDs (e.g., `["vault"]`, `["blob"]`)
  - `subnetResourceId` - Subnet where PE will be placed (`snet-private-endpoints`)
  - `privateDnsZoneResourceIds` - Array of DNS zone IDs for DNS registration
  - Standard params: `environment`, `location`, `tags`
- ✅ Outputs:
  - `privateEndpointResourceId`
  - `privateEndpointNetworkInterfaceId` (primary NIC)
  - `privateEndpointNetworkInterfaceIds` (all NICs)

### Usage Example

```bicep
// Key Vault Private Endpoint
module kvPrivateEndpoint '../workloads/bicep/private-endpoint.bicep' = {
  name: 'pe-kv'
  params: {
    environment: 'prod'
    location: location
    tags: tags
    privateEndpointName: 'pe-kv-prod-aue-01'
    targetResourceId: keyVault.outputs.resourceId
    groupIds: ['vault']
    subnetResourceId: subnetPrivateEndpoints.outputs.resourceId
    privateDnsZoneResourceIds: [
      dnsZoneKvResourceId  // From central DNS zones
    ]
  }
}

// Storage Account Blob Private Endpoint
module storageBlobPrivateEndpoint '../workloads/bicep/private-endpoint.bicep' = {
  name: 'pe-storage-blob'
  params: {
    environment: 'prod'
    location: location
    tags: tags
    privateEndpointName: 'pe-storage-blob-prod-aue-01'
    targetResourceId: storageAccount.outputs.resourceId
    groupIds: ['blob']
    subnetResourceId: subnetPrivateEndpoints.outputs.resourceId
    privateDnsZoneResourceIds: [
      dnsZoneBlobResourceId  // From central DNS zones
    ]
  }
}
```

---

## Architecture

```
Central Private DNS Zones (platform-connectivity subscription)
├── privatelink.vaultcore.azure.net
├── privatelink.blob.core.windows.net
├── privatelink.file.core.windows.net
└── ... (other zones)
    └── Linked to VNets via private-dns-links.bicep (per VNet opt-in)

Workload Subscription
├── Key Vault
│   └── Private Endpoint (workloads/bicep/private-endpoint.bicep)
│       ├── PE in snet-private-endpoints
│       └── DNS Group → privatelink.vaultcore.azure.net
└── Storage Account
    └── Private Endpoint (workloads/bicep/private-endpoint.bicep)
        ├── PE in snet-private-endpoints
        └── DNS Group → privatelink.blob.core.windows.net
```

---

## Configuration Pattern

### Enable/Disable DNS Zones

Edit `platform/connectivity/config/connectivity.prod.json`:

```json
{
  "connectivityConfig": {
    "enablePrivateDns": true,  // Set to false to skip DNS zone deployment
    "privateDnsZones": ["kv", "blob", "file"]  // Add/remove zones as needed
  }
}
```

---

## Key Features

1. **Centralized DNS**: All Private DNS zones in platform-connectivity subscription
2. **Configurable Linking**: Each VNet explicitly opts into zones it needs
3. **Generic PE Module**: Reusable for any PaaS service
4. **AVM Integration**: Uses AVM modules where available
5. **Loose Coupling**: DNS zones deployed separately from hub (not embedded)

---

## Files Created

1. `platform/connectivity/bicep/private-dns-zones.bicep`
2. `platform/connectivity/bicep/private-dns-links.bicep`
3. `platform/connectivity/config/connectivity.prod.json`
4. `workloads/bicep/private-endpoint.bicep`
5. `platform/connectivity/docs/PHASE5-IMPLEMENTATION.md`

---

## Files Modified

1. `platform/connectivity/scripts/deploy-connectivity.ps1` - Added DNS zone deployment orchestration

---

## Next Steps

1. Deploy hub with DNS zones:
   ```powershell
   ./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01"
   ```

2. Link DNS zones to VNets (as needed):
   - Hub VNet: Link all zones
   - Spoke VNets: Link only zones they use

3. Use Private Endpoint module in workload deployments:
   - Key Vault → `workloads/bicep/private-endpoint.bicep`
   - Storage Accounts → `workloads/bicep/private-endpoint.bicep`
   - SQL Databases → `workloads/bicep/private-endpoint.bicep`
