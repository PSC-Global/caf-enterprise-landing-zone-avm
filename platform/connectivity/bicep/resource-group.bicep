// =============================================================================
// Networking Resource Group
// =============================================================================
// Purpose: Creates networking resource group for vWAN hub or spoke vNet
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

var networkingRgName = 'rg-${subscriptionPurpose}-network-${primaryRegion}-001'

// =============================================================================
// Networking Resource Group using AVM
// =============================================================================

module networkingResourceGroup 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'rg-network-${uniqueString(deployment().name)}'
  params: {
    name: networkingRgName
    location: primaryRegion
    tags: union(tags, {
      purpose: 'networking'
    })
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Networking resource group name')
output networkingRgName string = networkingResourceGroup.outputs.name

@description('Networking resource group resource ID')
output networkingRgResourceId string = networkingResourceGroup.outputs.resourceId

