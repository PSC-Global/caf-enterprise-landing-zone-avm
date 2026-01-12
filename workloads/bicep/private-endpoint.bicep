// =============================================================================
// Generic Private Endpoint Module
// =============================================================================
// Purpose: Creates Private Endpoints for PaaS services (Key Vault, Storage, SQL, etc.)
// Scope: Resource Group
// AVM: avm/res/network/private-endpoint
// Contract: Follows platform/shared/contract.bicep standards
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

@description('Private Endpoint name')
param privateEndpointName string

@description('Target PaaS resource ID (e.g., Key Vault, Storage Account)')
param targetResourceId string

@description('Array of group IDs for the private endpoint (e.g., ["vault"], ["blob"], ["file"])')
param groupIds array

@description('Subnet resource ID where the Private Endpoint will be placed')
param subnetResourceId string

@description('Array of Private DNS zone resource IDs for DNS registration')
param privateDnsZoneResourceIds array = []

@description('Private Link Service Connection name (optional, auto-generated if not provided)')
param connectionName string = ''

@description('Request message for manual approval (optional)')
param requestMessage string = ''

// =============================================================================
// Connection Name Generation
// =============================================================================

var targetResourceName = last(split(targetResourceId, '/'))
var targetResourceType = split(split(targetResourceId, '/')[7], '/')[0]
var effectiveConnectionName = !empty(connectionName) ? connectionName : '${targetResourceName}-connection'

// =============================================================================
// Private DNS Zone Group Configuration
// =============================================================================

var dnsZoneGroupConfigs = [for (dnsZoneId, i) in privateDnsZoneResourceIds: {
  name: 'dns-zone-${i}'
  privateDnsZoneResourceId: dnsZoneId
}]

// =============================================================================
// Private Endpoint using AVM
// =============================================================================

module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.9.0' = {
  name: 'pe-${uniqueString(resourceGroup().id)}'
  params: {
    name: privateEndpointName
    location: location
    tags: union(tags, {
      purpose: 'private-endpoint'
      targetResource: targetResourceType
      targetResourceId: targetResourceId
      environment: environment
    })
    subnetResourceId: subnetResourceId
    privateLinkServiceConnections: [
      {
        name: effectiveConnectionName
        properties: {
          groupIds: groupIds
          privateLinkServiceId: targetResourceId
          requestMessage: requestMessage
        }
      }
    ]
    privateDnsZoneGroup: length(privateDnsZoneResourceIds) > 0 ? {
      name: 'default'
      privateDnsZoneGroupConfigs: dnsZoneGroupConfigs
    } : null
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Private Endpoint resource ID')
output privateEndpointResourceId string = privateEndpoint.outputs.resourceId

@description('Private Endpoint name')
output privateEndpointName string = privateEndpoint.outputs.name

@description('Private Endpoint network interface ID (primary NIC)')
output privateEndpointNetworkInterfaceId string = length(privateEndpoint.outputs.networkInterfaceResourceIds) > 0 ? privateEndpoint.outputs.networkInterfaceResourceIds[0] : ''

@description('All Private Endpoint network interface IDs')
output privateEndpointNetworkInterfaceIds array = privateEndpoint.outputs.networkInterfaceResourceIds

@description('Private Endpoint IP address (if available)')
output privateEndpointIpAddress string = length(privateEndpoint.outputs.networkInterfaceResourceIds) > 0 ? '' : ''
