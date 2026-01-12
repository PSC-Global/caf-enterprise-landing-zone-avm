// =============================================================================
// Virtual Hub Route Intent (Forced Egress)
// =============================================================================
// Purpose: Implements forced egress through Azure Firewall for all vWAN-connected spokes
// Scope: Resource Group
// Note: Using native Bicep - route intent is a vWAN-specific feature
// Contract: Follows platform/shared/contract.bicep standards
// =============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Module-Specific Parameters
// -----------------------------------------------------------------------------
// Note: Standard platform parameters (environment, location, tags) are not needed
// for Routing Intent as it's a child resource that inherits from the Virtual Hub.

@description('Virtual Hub resource ID')
param virtualHubResourceId string

@description('Azure Firewall resource ID (next hop for forced egress)')
param azureFirewallResourceId string

@description('Route Intent name (optional, will be generated if not provided)')
param routeIntentName string = ''

// =============================================================================
// Route Intent Configuration
// =============================================================================

var hubName = last(split(virtualHubResourceId, '/'))
var effectiveRouteIntentName = !empty(routeIntentName) ? routeIntentName : 'routing-intent-${hubName}'

// =============================================================================
// Virtual Hub Route Intent Resource
// =============================================================================
// Route Intent forces internet traffic (0.0.0.0/0) from all connected spokes
// through the Azure Firewall for security and compliance.
// 
// IMPORTANT: Routing Intent and custom route tables are mutually exclusive.
// When Routing Intent is enabled, it automatically handles routing for ALL
// connected spokes - no custom route tables are needed or allowed.
// 
// Note: Using full resource name format for child resource (hubName/routingIntentName)

resource routingIntent 'Microsoft.Network/virtualHubs/routingIntent@2024-03-01' = {
  name: '${hubName}/${effectiveRouteIntentName}'
  properties: {
    routingPolicies: [
      {
        name: 'InternetTrafficPolicy'
        destinations: [
          'Internet'
        ]
        nextHop: azureFirewallResourceId
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================
// Note: Routing Intent automatically handles internet traffic routing for ALL
// connected spokes. No custom route tables are needed when Routing Intent is enabled.
// Routing Intent and custom route tables are mutually exclusive in Azure Virtual WAN.

@description('Routing Intent resource ID')
output routingIntentResourceId string = routingIntent.id

// Legacy outputs for backward compatibility (deprecated - Routing Intent handles routing automatically)
@description('DEPRECATED: Routing Intent handles routing automatically. Use routingIntentResourceId instead.')
output routeTableResourceId string = ''

@description('DEPRECATED: Routing Intent handles routing automatically.')
output routeTableName string = ''
