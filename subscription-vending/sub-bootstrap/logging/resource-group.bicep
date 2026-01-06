// =============================================================================
// Logging Resource Group
// =============================================================================
// Purpose: Creates logging resource group for Log Analytics workspace and diagnostics
// Scope: Subscription
// AVM: avm/res/resources/resource-group
// =============================================================================

targetScope = 'subscription'

@description('Primary region for resource deployment')
param primaryRegion string

@description('Subscription purpose for naming convention')
param subscriptionPurpose string

@description('Tags to apply to resource group')
param tags object

// =============================================================================
// Resource Group Naming
// =============================================================================

var loggingRgName = 'rg-${subscriptionPurpose}-logging-${primaryRegion}-001'

// =============================================================================
// Logging Resource Group using AVM
// =============================================================================

module loggingResourceGroup 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'rg-logging-${uniqueString(deployment().name)}'
  params: {
    name: loggingRgName
    location: primaryRegion
    tags: union(tags, {
      purpose: 'logging'
    })
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Logging resource group name')
output loggingRgName string = loggingResourceGroup.outputs.name

@description('Logging resource group resource ID')
output loggingRgResourceId string = loggingResourceGroup.outputs.resourceId

