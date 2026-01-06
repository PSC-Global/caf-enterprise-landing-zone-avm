// =============================================================================
// vWAN Hub Deployment
// =============================================================================
// Purpose: Deploys Virtual WAN and Virtual Hub infrastructure
// Scope: Resource Group
// AVM: avm/res/network/virtual-wan, avm/res/network/virtual-hub
// =============================================================================

targetScope = 'resourceGroup'

@description('Virtual WAN name')
param vwanName string

@description('Virtual Hub name')
param vhubName string

@description('Location for resources')
param location string

@description('Tags to apply to resources')
param tags object

@description('Virtual Hub address prefix (e.g., 10.0.0.0/23)')
param vhubAddressPrefix string

@description('Enable Azure Firewall in the hub')
param enableFirewall bool = true

@description('Azure Firewall SKU')
@allowed([
  'Standard'
  'Premium'
])
param firewallSku string = 'Standard'

@description('Enable VPN Gateway')
param enableVpnGateway bool = false

@description('VPN Gateway scale units')
@minValue(1)
@maxValue(100)
param vpnGatewayScaleUnits int = 1

@description('Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Virtual WAN using AVM
// =============================================================================

module virtualWan 'br/public:avm/res/network/virtual-wan:0.4.3' = {
  name: 'vwan-${uniqueString(resourceGroup().id)}'
  params: {
    name: vwanName
    location: location
    tags: tags
    // Note: Older AVM version only supports basic parameters
    // Advanced features like diagnosticSettings not available in 0.4.3
  }
}

// =============================================================================
// Virtual Hub using AVM
// =============================================================================

module virtualHub 'br/public:avm/res/network/virtual-hub:0.4.3' = {
  name: 'vhub-${uniqueString(resourceGroup().id)}'
  params: {
    name: vhubName
    location: location
    tags: tags
    addressPrefix: vhubAddressPrefix
    virtualWanResourceId: virtualWan.outputs.resourceId
    // Note: Simplified parameters for 0.4.3 compatibility
    // Diagnostic settings must be added separately if needed
  }
  dependsOn: [
    virtualWan
  ]
}

// =============================================================================
// Azure Firewall using AVM (if enabled)
// =============================================================================

module azureFirewall 'br/public:avm/res/network/azure-firewall:0.9.2' = if (enableFirewall) {
  name: 'fw-${uniqueString(resourceGroup().id)}'
  params: {
    name: 'fw-${vhubName}'
    location: location
    tags: tags
    azureSkuTier: firewallSku
    virtualHubResourceId: virtualHub.outputs.resourceId
    publicIPResourceID: null // vWAN-integrated firewalls don't need public IPs (singular, different casing in 0.7.1)
    // Note: Diagnostic settings not supported in azure-firewall 0.7.1 params
    // Must be added separately if needed
  }
  dependsOn: [
    virtualHub
  ]
}

// =============================================================================
// VPN Gateway using AVM (if enabled)
// =============================================================================

module vpnGateway 'br/public:avm/res/network/vpn-gateway:0.2.2' = if (enableVpnGateway) {
  name: 'vpng-${uniqueString(resourceGroup().id)}'
  params: {
    name: 'vpng-${vhubName}'
    location: location
    tags: tags
    virtualHubResourceId: virtualHub.outputs.resourceId
    bgpSettings: {
      asn: 65515
    }
    // Note: Diagnostic settings not supported in vpn-gateway 0.2.2 params
    // Must be added separately if needed
  }
  dependsOn: [
    virtualHub
  ]
}

// =============================================================================
// Outputs
// =============================================================================

@description('Virtual WAN name')
output vwanName string = virtualWan.outputs.name

@description('Virtual WAN resource ID')
output vwanResourceId string = virtualWan.outputs.resourceId

@description('Virtual Hub name')
output vhubName string = virtualHub.outputs.name

@description('Virtual Hub resource ID')
output vhubResourceId string = virtualHub.outputs.resourceId

@description('Virtual Hub address prefix')
output vhubAddressPrefix string = vhubAddressPrefix

@description('Azure Firewall resource ID')
output firewallResourceId string = enableFirewall ? azureFirewall.outputs.resourceId : ''

@description('VPN Gateway resource ID')
output vpnGatewayResourceId string = enableVpnGateway ? vpnGateway.outputs.resourceId : ''
