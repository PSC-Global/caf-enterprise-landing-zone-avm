// =============================================================================
// Private DNS Zone Virtual Network Links
// =============================================================================
// Purpose: Links Private DNS zones to Virtual Networks for DNS resolution
// Scope: Resource Group (must be in same subscription as DNS zones)
// Note: Using native Bicep - AVM module for DNS links not available
// Contract: Follows platform/shared/contract.bicep standards
// =============================================================================
// Usage: Each VNet explicitly opts into the zones it needs
// Example: Spoke VNet links to kv and blob zones only if it uses Key Vault and Storage
// =============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Standard Platform Parameters (from platform/shared/contract.bicep)
// -----------------------------------------------------------------------------

@description('Deployment environment')
param environment string = 'prod'

@description('Azure region for resource deployment')
param location string

@description('Tags to apply to all resources')
param tags object

// -----------------------------------------------------------------------------
// Module-Specific Parameters
// -----------------------------------------------------------------------------

@description('Virtual Network resource ID to link zones to')
param virtualNetworkResourceId string

@description('Virtual Network name (for link naming, extracted if not provided)')
param virtualNetworkName string = ''

@description('Array of Private DNS zone configurations with zone name and resource group')
param privateDnsZoneConfigs array = []

// Note: Each zone config should have:
// {
//   zoneResourceId: "/subscriptions/.../privateDnsZones/privatelink.vaultcore.azure.net"
//   zoneName: "privatelink.vaultcore.azure.net"
//   zoneResourceGroup: "rg-..."
// }

@description('Registration enabled flag (true = auto-register VNet records in zone)')
param registrationEnabled bool = false

// =============================================================================
// Virtual Network Name Extraction
// =============================================================================

var vnetName = !empty(virtualNetworkName) ? virtualNetworkName : last(split(virtualNetworkResourceId, '/'))

// =============================================================================
// Private DNS Zone Virtual Network Links (Native Bicep)
// =============================================================================
// Note: AVM module for DNS zone VNet links is not available
// Using native Bicep resource definition following Azure best practices
// Parent must reference the zone as a child resource using zone name format

resource privateDnsLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (zoneConfig, i) in privateDnsZoneConfigs: {
  name: 'link-${vnetName}-${i}'
  parent: resourceId(subscription().subscriptionId, zoneConfig.zoneResourceGroup, 'Microsoft.Network/privateDnsZones', zoneConfig.zoneName)
  location: location
  tags: union(tags, {
    purpose: 'private-dns-link'
    environment: environment
    linkedVNet: vnetName
    zoneKey: zoneConfig.zoneKey ?? ''
  })
  properties: {
    virtualNetwork: {
      id: virtualNetworkResourceId
    }
    registrationEnabled: registrationEnabled
  }
}]

// =============================================================================
// Outputs
// =============================================================================

@description('Virtual network links resource IDs')
output virtualNetworkLinkResourceIds array = [for (link, i) in privateDnsLinks: link.id]

@description('Virtual network link names')
output virtualNetworkLinkNames array = [for (link, i) in privateDnsLinks: link.name]
