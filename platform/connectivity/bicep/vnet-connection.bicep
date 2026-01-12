// =============================================================================
// Virtual Hub VNet Connection with Route Table Association
// =============================================================================
// Purpose: Connects spoke VNet to vHub and associates route table for forced egress
// Scope: Resource Group (deployed to hub resource group)
// Note: Using native Bicep - route table association on connections requires native resources
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

@description('Virtual Hub resource ID')
param virtualHubResourceId string

@description('Virtual Hub name (extracted from resource ID if not provided)')
param virtualHubName string = ''

@description('Remote Virtual Network resource ID (spoke VNet to connect)')
param remoteVirtualNetworkResourceId string

@description('Connection name (optional, will be generated if not provided)')
param connectionName string = ''

@description('Route table resource ID to associate with connection (for forced egress)')
param routeTableResourceId string = ''

@description('Enable Internet security (route to firewall)')
param enableInternetSecurity bool = true

@description('Allow hub to remote VNet transit')
param allowHubToRemoteVnetTransit bool = true

@description('Allow remote VNet to use hub gateways')
param allowRemoteVnetToUseHubVnetGateways bool = true

// =============================================================================
// Connection Name Generation
// =============================================================================

var hubName = !empty(virtualHubName) ? virtualHubName : last(split(virtualHubResourceId, '/'))
var vnetName = last(split(remoteVirtualNetworkResourceId, '/'))
var effectiveConnectionName = !empty(connectionName) ? connectionName : '${vnetName}-connection'

// =============================================================================
// Virtual Hub Connection
// =============================================================================
// Note: Parent must be referenced by resource ID as a string in the resource name
// Bicep will automatically handle the parent-child relationship

resource hubConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-03-01' = {
  name: '${hubName}/${effectiveConnectionName}'
  properties: {
    remoteVirtualNetwork: {
      id: remoteVirtualNetworkResourceId
    }
    allowHubToRemoteVnetTransit: allowHubToRemoteVnetTransit
    allowRemoteVnetToUseHubVnetGateways: allowRemoteVnetToUseHubVnetGateways
    enableInternetSecurity: enableInternetSecurity
    routingConfiguration: !empty(routeTableResourceId) ? {
      associatedRouteTable: {
        id: routeTableResourceId
      }
      propagatedRouteTables: {
        labels: [
          'default'
        ]
        ids: [
          {
            id: routeTableResourceId
          }
        ]
      }
      vnetRoutes: {
        staticRoutes: []
      }
    } : null
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Hub connection resource ID')
output connectionResourceId string = hubConnection.id

@description('Connection name')
output connectionName string = last(split(hubConnection.name, '/'))

@description('Virtual Hub resource ID (output)')
output hubResourceId string = virtualHubResourceId

@description('Remote VNet resource ID (output)')
output vnetResourceId string = remoteVirtualNetworkResourceId
