// =============================================================================
// Logging Resource Group
// =============================================================================
// Purpose: Creates resource group for central logging infrastructure
// Scope: Subscription
// AVM: avm/res/resources/resource-group
// Contract: Follows platform/shared/contract.bicep standards
// =============================================================================

targetScope = 'subscription'

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

@description('Resource group name (optional, will be generated if not provided)')
param resourceGroupName string = ''

// =============================================================================
// Resource Group Naming
// =============================================================================

var rgName = !empty(resourceGroupName) ? resourceGroupName : 'rg-rai-${environment}-${location}-logging-001'

// =============================================================================
// Logging Resource Group using AVM
// =============================================================================

module loggingResourceGroup 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'rg-logging-${uniqueString(deployment().name)}'
  params: {
    name: rgName
    location: location
    tags: union(tags, {
      purpose: 'logging'
      managedBy: 'platform-logging'
    })
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Logging resource group name')
output resourceGroupName string = loggingResourceGroup.outputs.name

@description('Logging resource group resource ID')
output resourceGroupResourceId string = loggingResourceGroup.outputs.resourceId
