// =============================================================================
// Central Private DNS Zones
// =============================================================================
// Purpose: Creates centralized Private DNS zones for PaaS services
// Scope: Resource Group
// AVM: avm/res/network/private-dns-zone
// Contract: Follows platform/shared/contract.bicep standards
// =============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Standard Platform Parameters (from platform/shared/contract.bicep)
// -----------------------------------------------------------------------------

@description('Deployment environment')
param environment string = 'prod'

@description('Azure region for resource deployment (not used for Private DNS zones - they are global)')
@metadata({
  'unused': 'Private DNS zones are global resources. Location parameter kept for backward compatibility but not passed to AVM module.'
})
param location string

@description('Tags to apply to all resources')
param tags object

// -----------------------------------------------------------------------------
// Module-Specific Parameters
// -----------------------------------------------------------------------------

@description('Array of Private DNS zone configurations to create')
param privateDnsZoneConfigs array = []

// =============================================================================
// Private DNS Zone Mapping
// =============================================================================
// Maps zone keys (e.g., "kv", "blob") to actual zone names

var zoneMapping = {
  kv: 'privatelink.vaultcore.azure.net'
  blob: 'privatelink.blob.core.windows.net'
  file: 'privatelink.file.core.windows.net'
  queue: 'privatelink.queue.core.windows.net'
  table: 'privatelink.table.core.windows.net'
  dfs: 'privatelink.dfs.core.windows.net'
  sql: 'privatelink.database.windows.net'
  postgresql: 'privatelink.postgres.database.azure.com'
  mysql: 'privatelink.mysql.database.azure.com'
  mariadb: 'privatelink.mariadb.database.azure.com'
  redis: 'privatelink.redis.cache.windows.net'
  servicebus: 'privatelink.servicebus.windows.net'
  eventhub: 'privatelink.servicebus.windows.net'
  cosmos: 'privatelink.documents.azure.com'
  appservice: 'privatelink.azurewebsites.net'
  appserviceenvironment: 'privatelink.appserviceenvironment.net'
}

// =============================================================================
// Region Short Code for Naming (optional - reserved for future use)
// =============================================================================

// Note: Region code calculation reserved for future naming enhancements

// =============================================================================
// Private DNS Zones using AVM
// =============================================================================

module privateDnsZones 'br/public:avm/res/network/private-dns-zone:0.7.1' = [for (zoneConfig, i) in privateDnsZoneConfigs: {
  name: 'pdns-${uniqueString(resourceGroup().id)}-${i}'
  params: {
    name: zoneMapping[zoneConfig.key]
    // Note: location parameter not passed - AVM module defaults to "global" which is required for Private DNS zones
    // Private DNS zones are global resources and cannot be regional
    tags: union(tags, {
      purpose: 'private-dns'
      service: zoneConfig.key
      environment: environment
      managedBy: 'platform-connectivity'
    })
  }
}]

// =============================================================================
// Outputs
// =============================================================================

@description('Array of zone configurations with resource IDs')
output privateDnsZones array = [for (zoneConfig, i) in privateDnsZoneConfigs: {
  key: zoneConfig.key
  zoneName: zoneMapping[zoneConfig.key]
  resourceId: privateDnsZones[i].outputs.resourceId
  name: privateDnsZones[i].outputs.name
}]

@description('Private DNS zone resource IDs (for easy lookup by index)')
output privateDnsZoneResourceIds array = [for (zoneConfig, i) in privateDnsZoneConfigs: privateDnsZones[i].outputs.resourceId]

@description('Private DNS zone names (for easy lookup by index)')
output privateDnsZoneNames array = [for (zoneConfig, i) in privateDnsZoneConfigs: privateDnsZones[i].outputs.name]
