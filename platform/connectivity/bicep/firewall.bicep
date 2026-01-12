// =============================================================================
// Azure Firewall
// =============================================================================
// Purpose: Deploys Azure Firewall attached to Virtual Hub (Phase B - Security Edge)
// Scope: Resource Group
// AVM: avm/res/network/azure-firewall
// Contract: Follows platform/shared/contract.bicep standards
// Lifecycle: More frequent changes - security edge service
// Dependencies: Requires Virtual Hub (Phase A) and Firewall Policy (Phase B.1)
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

@description('Virtual Hub resource ID (from hub-core deployment)')
param virtualHubResourceId string

@description('Virtual Hub name (for resource naming)')
param vhubName string

@description('Firewall Policy resource ID (required, from firewall-policy deployment)')
param firewallPolicyResourceId string

@description('Azure Firewall SKU')
@allowed([
  'Standard'
  'Premium'
])
param firewallSku string = 'Standard'

// =============================================================================
// Azure Firewall using AVM
// =============================================================================

module azureFirewall 'br/public:avm/res/network/azure-firewall:0.9.2' = {
  name: 'fw-${uniqueString(resourceGroup().id)}'
  params: {
    name: 'fw-${vhubName}'
    location: location
    tags: tags
    azureSkuTier: firewallSku
    virtualHubResourceId: virtualHubResourceId
    publicIPResourceID: null // vWAN-integrated firewalls don't need public IPs (singular, different casing in 0.7.1)
    firewallPolicyId: firewallPolicyResourceId
    // Note: Diagnostic settings not supported in azure-firewall 0.9.2 params
    // Must be added separately if needed
  }
}

// =============================================================================
// Outputs
// =============================================================================
// Standard outputs following platform/shared/contract.bicep naming conventions

@description('Azure Firewall resource ID (standard output)')
output azureFirewallResourceId string = azureFirewall.outputs.resourceId

@description('Azure Firewall name')
output azureFirewallName string = azureFirewall.outputs.name

// Legacy output names (deprecated - use standard names above)
@description('DEPRECATED: Use azureFirewallResourceId instead')
output firewallResourceId string = azureFirewall.outputs.resourceId
