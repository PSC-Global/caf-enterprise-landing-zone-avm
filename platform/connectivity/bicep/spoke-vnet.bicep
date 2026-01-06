// =============================================================================
// Spoke Virtual Network
// =============================================================================
// Purpose: Deploys a spoke VNet and connects it to the vWAN hub
// Scope: Resource Group
// AVM: avm/res/network/virtual-network
// =============================================================================

targetScope = 'resourceGroup'

@description('Virtual network name')
param vnetName string

@description('Location for the virtual network')
param location string

@description('Tags to apply to the virtual network')
param tags object

@description('VNet address prefixes (from IPAM or manual)')
param addressPrefixes array

@description('Subnets configuration')
param subnets array = []

@description('Enable DDoS protection')
param enableDdosProtection bool = false

@description('DDoS protection plan resource ID')
param ddosProtectionPlanId string = ''

@description('Virtual Hub resource ID for connection')
param virtualHubResourceId string = ''

@description('Enable Internet security (route to firewall)')
param enableInternetSecurity bool = true

@description('Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

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
    diagnosticSettings: !empty(logAnalyticsWorkspaceId) ? [
      {
        name: 'vnet-diagnostics'
        workspaceResourceId: logAnalyticsWorkspaceId
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
// Virtual Hub Connection (inline resource)
// =============================================================================
// Note: AVM for virtual-hub doesn't yet fully support connections, so we use
// native Bicep for the hub connection as a child resource.
// =============================================================================

resource hubConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-01-01' = if (!empty(virtualHubResourceId)) {
  name: '${last(split(virtualHubResourceId, '/'))}/${vnetName}-connection'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork.outputs.resourceId
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: enableInternetSecurity
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

@description('Hub connection resource ID')
output hubConnectionResourceId string = !empty(virtualHubResourceId) ? hubConnection.id : ''
