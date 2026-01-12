// =============================================================================
// vWAN Hub Deployment
// =============================================================================
// Purpose: Deploys Virtual WAN and Virtual Hub infrastructure
// Scope: Resource Group
// AVM: avm/res/network/virtual-wan, avm/res/network/virtual-hub
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

@description('Log Analytics Workspace resource ID for diagnostics (reserved for future PowerShell-based diagnostic deployment)')
@metadata({
  'unused': 'Intentionally unused in Bicep - diagnostics configured via PowerShell post-deployment'
})
param logAnalyticsWorkspaceResourceId string = ''

// -----------------------------------------------------------------------------
// Module-Specific Parameters
// -----------------------------------------------------------------------------

@description('Virtual WAN name')
param vwanName string

@description('Virtual Hub name')
param vhubName string

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

@description('Firewall Policy resource ID (required when enableFirewall is true)')
param firewallPolicyResourceId string = ''

@description('Enable forced egress routing through firewall (creates route intent)')
param enableForcedEgress bool = true

@description('Enable VPN Gateway')
param enableVpnGateway bool = false

// Note: VPN Gateway scale units parameter removed - AVM vpn-gateway:0.2.2 doesn't support
// scale units parameter. Scale is managed via the gateway SKU/tier instead.

// =============================================================================
// Firewall Policy
// =============================================================================
// Note: Firewall Policy must be deployed separately (not as a nested module)
// to avoid deployment conflicts with stable module names.
// The firewallPolicyResourceId should be provided from a separate deployment.

var effectiveFirewallPolicyId = firewallPolicyResourceId


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
// Diagnostic Settings for Virtual WAN
// =============================================================================
// Note: Diagnostic settings cannot be scoped using resourceId() when resources are created
// via AVM modules. Diagnostics must be configured separately via Azure Policy or
// deployed via PowerShell/CLI after resource creation.
// TODO: Implement diagnostic settings deployment via PowerShell script or Azure Policy

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
// Diagnostic Settings for Virtual Hub
// =============================================================================
// Note: Diagnostic settings cannot be scoped using resourceId() when resources are created
// via AVM modules. Diagnostics must be configured separately via Azure Policy or
// deployed via PowerShell/CLI after resource creation.
// TODO: Implement diagnostic settings deployment via PowerShell script or Azure Policy

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
    firewallPolicyId: effectiveFirewallPolicyId
    // Note: Diagnostic settings not supported in azure-firewall 0.9.2 params
    // Must be added separately if needed
  }
  dependsOn: [
    virtualHub
  ]
}

// =============================================================================
// Diagnostic Settings for Azure Firewall
// =============================================================================
// Note: Diagnostic settings cannot be scoped when resources are created via AVM modules.
// Diagnostics must be configured separately via Azure Policy (Phase 9) or
// deployed via PowerShell/CLI after resource creation.
// The logAnalyticsWorkspaceResourceId parameter is kept for future PowerShell-based diagnostic deployment.

// =============================================================================
// Route Intent - Forced Egress through Firewall (Phase 3.3)
// =============================================================================

module routeIntent './route-intent.bicep' = if (enableFirewall && enableForcedEgress) {
  name: 'route-intent-${uniqueString(resourceGroup().id)}'
  params: {
    virtualHubResourceId: virtualHub.outputs.resourceId
    azureFirewallResourceId: azureFirewall.outputs.resourceId
  }
  dependsOn: [
    azureFirewall
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

@description('Azure Firewall resource ID (standard output)')
output azureFirewallResourceId string = enableFirewall ? azureFirewall.outputs.resourceId : ''

@description('Firewall Policy resource ID')
output firewallPolicyResourceId string = effectiveFirewallPolicyId

@description('Route Intent resource ID (if forced egress enabled)')
output routingIntentResourceId string = (enableFirewall && enableForcedEgress) ? routeIntent.outputs.routingIntentResourceId : ''

@description('DEPRECATED: Routing Intent handles routing automatically. No route tables needed.')
output routeTableResourceId string = ''

@description('DEPRECATED: Routing Intent handles routing automatically. No route tables needed.')
output routeTableName string = ''

@description('VPN Gateway resource ID')
output vpnGatewayResourceId string = enableVpnGateway ? vpnGateway.outputs.resourceId : ''

// Legacy output names (deprecated - use standard names above)
@description('DEPRECATED: Use virtualWanResourceId instead')
output vwanResourceId string = virtualWan.outputs.resourceId

@description('DEPRECATED: Use virtualHubResourceId instead')
output vhubResourceId string = virtualHub.outputs.resourceId

@description('DEPRECATED: Use azureFirewallResourceId instead')
output firewallResourceId string = enableFirewall ? azureFirewall.outputs.resourceId : ''
