// =============================================================================
// Subscription Alias Creation (MCA)
// =============================================================================
// Purpose: Creates a new Azure subscription via Subscription Alias for MCA
// Scope: Tenant Root (subscription alias is a tenant-scope resource)
// API: Microsoft.Subscription/aliases@2021-10-01
// =============================================================================

targetScope = 'tenant'

@description('Subscription alias name - must be unique across the tenant')
param aliasName string

@description('Display name for the new subscription')
param displayName string

@description('Billing scope for MCA subscription creation')
param billingScope string

@description('Workload type for the subscription')
@allowed([
  'Production'
  'DevTest'
])
param workload string = 'Production'

@description('Tags to apply to the subscription')
param tags object = {}

// =============================================================================
// Subscription Alias Resource
// =============================================================================

resource subscriptionAlias 'Microsoft.Subscription/aliases@2021-10-01' = {
  name: aliasName
  properties: {
    displayName: displayName
    billingScope: billingScope
    workload: workload
    additionalProperties: {
      tags: tags
      subscriptionOwnerId: ''
      subscriptionTenantId: tenant().tenantId
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('The created subscription ID')
output subscriptionId string = subscriptionAlias.properties.subscriptionId

@description('The subscription alias resource ID')
output aliasResourceId string = subscriptionAlias.id

@description('The subscription display name')
output subscriptionName string = displayName

@description('The provisioning state')
output provisioningState string = subscriptionAlias.properties.provisioningState
