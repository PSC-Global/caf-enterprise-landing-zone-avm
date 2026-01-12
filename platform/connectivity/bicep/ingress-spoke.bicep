// =============================================================================
// Ingress Spoke Virtual Network
// =============================================================================
// Purpose: Deploys ingress spoke VNet with Application Gateway subnet
// Scope: Resource Group
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

@description('Log Analytics Workspace resource ID for diagnostics')
param logAnalyticsWorkspaceResourceId string = ''

// -----------------------------------------------------------------------------
// Module-Specific Parameters
// -----------------------------------------------------------------------------

@description('Virtual network name')
param vnetName string

@description('VNet address prefixes (from IPAM or manual)')
param addressPrefixes array

@description('Subnets configuration (generated from spoke.ingress.appgw profile)')
param subnets array = []

@description('Virtual Hub resource ID for connection')
param virtualHubResourceId string = ''

@description('Virtual Hub name (for connection name generation)')
param virtualHubName string = ''

@description('Route table resource ID for forced egress')
param routeTableResourceId string = ''

@description('Enable DDoS protection')
param enableDdosProtection bool = false

@description('DDoS protection plan resource ID')
param ddosProtectionPlanId string = ''

@description('DNS servers (empty array for Azure-provided DNS)')
param dnsServers array = []

// =============================================================================
// Virtual Network using AVM
// =============================================================================

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: 'vnet-${uniqueString(resourceGroup().id)}'
  params: {
    name: vnetName
    location: location
    tags: tags
    addressPrefixes: addressPrefixes
    subnets: subnets
    dnsServers: dnsServers
    ddosProtectionPlanResourceId: enableDdosProtection ? ddosProtectionPlanId : ''
    diagnosticSettings: !empty(logAnalyticsWorkspaceResourceId) ? [
      {
        name: 'vnet-diagnostics'
        workspaceResourceId: logAnalyticsWorkspaceResourceId
        logCategoriesAndGroups: [
          {
            categoryGroup: 'allLogs'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
      }
    ] : []
  }
}

// =============================================================================
// Virtual Hub Connection with Route Table Association
// =============================================================================

var hubName = !empty(virtualHubName) ? virtualHubName : last(split(virtualHubResourceId, '/'))

resource hubConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-03-01' = if (!empty(virtualHubResourceId)) {
  name: '${hubName}/${vnetName}-connection'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork.outputs.resourceId
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
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

@description('Virtual network name')
output name string = virtualNetwork.outputs.name

@description('Virtual network resource ID')
output resourceId string = virtualNetwork.outputs.resourceId

@description('Virtual network address prefixes')
output addressPrefixes array = addressPrefixes

@description('Subnet resource IDs')
output subnetResourceIds array = virtualNetwork.outputs.subnetResourceIds

@description('Application Gateway subnet resource ID')
output appGatewaySubnetResourceId string = virtualNetwork.outputs.subnetResourceIds[0] // First subnet should be snet-appgw

@description('Workload subnet resource ID')
output workloadSubnetResourceId string = length(virtualNetwork.outputs.subnetResourceIds) > 1 ? virtualNetwork.outputs.subnetResourceIds[1] : ''

@description('Private endpoints subnet resource ID')
output privateEndpointsSubnetResourceId string = length(virtualNetwork.outputs.subnetResourceIds) > 2 ? virtualNetwork.outputs.subnetResourceIds[2] : ''

@description('Hub connection resource ID')
output hubConnectionResourceId string = !empty(virtualHubResourceId) ? hubConnection.id : ''
