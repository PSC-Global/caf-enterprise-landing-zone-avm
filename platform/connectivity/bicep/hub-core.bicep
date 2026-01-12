// =============================================================================
// Hub Core (vWAN + vHub)
// =============================================================================
// Purpose: Deploys Virtual WAN and Virtual Hub infrastructure (Phase A - Hub Core)
// Scope: Resource Group
// AVM: avm/res/network/virtual-wan, avm/res/network/virtual-hub
// Contract: Follows platform/shared/contract.bicep standards
// Lifecycle: Rare changes - core hub foundation
// =============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Standard Platform Parameters (from platform/shared/contract.bicep)
// -----------------------------------------------------------------------------

@description('Deployment environment (standard platform parameter)')
@metadata({
  'unused': 'Standard platform parameter - reserved for future use'
})
param environment string = 'prod'

@description('Azure region for resource deployment')
param location string

@description('Tags to apply to all resources')
param tags object

// -----------------------------------------------------------------------------
// Module-Specific Parameters
// -----------------------------------------------------------------------------

@description('Virtual WAN name')
param vwanName string

@description('Virtual Hub name')
param vhubName string

@description('Virtual Hub address prefix (e.g., 10.0.0.0/23)')
param vhubAddressPrefix string

@description('Enable VPN Gateway (optional)')
param enableVpnGateway bool = false

@description('Unique deployment suffix for module names (prevents deployment conflicts)')
param deploymentSuffix string = uniqueString(resourceGroup().id)

// =============================================================================
// Virtual WAN using AVM
// =============================================================================

module virtualWan 'br/public:avm/res/network/virtual-wan:0.4.3' = {
  name: 'vwan-${deploymentSuffix}'
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
  name: 'vhub-${deploymentSuffix}'
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
// VPN Gateway using AVM (optional)
// =============================================================================

module vpnGateway 'br/public:avm/res/network/vpn-gateway:0.2.2' = if (enableVpnGateway) {
  name: 'vpng-${deploymentSuffix}'
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
// Standard outputs following platform/shared/contract.bicep naming conventions

@description('Virtual WAN name')
output vwanName string = virtualWan.outputs.name

@description('Virtual WAN resource ID (standard output)')
output virtualWanResourceId string = virtualWan.outputs.resourceId

@description('Virtual WAN ID (for references)')
output vwanId string = virtualWan.outputs.resourceId

@description('Virtual Hub name')
output vhubName string = virtualHub.outputs.name

@description('Virtual Hub resource ID (standard output)')
output virtualHubResourceId string = virtualHub.outputs.resourceId

@description('Virtual Hub ID (for references)')
output vhubId string = virtualHub.outputs.resourceId

@description('Virtual Hub address prefix')
output vhubAddressPrefix string = vhubAddressPrefix

@description('VPN Gateway resource ID (if enabled)')
output vpnGatewayResourceId string = enableVpnGateway ? vpnGateway.outputs.resourceId : ''

// Legacy output names (deprecated - use standard names above)
@description('DEPRECATED: Use virtualWanResourceId instead')
output vwanResourceId string = virtualWan.outputs.resourceId

@description('DEPRECATED: Use virtualHubResourceId instead')
output vhubResourceId string = virtualHub.outputs.resourceId
