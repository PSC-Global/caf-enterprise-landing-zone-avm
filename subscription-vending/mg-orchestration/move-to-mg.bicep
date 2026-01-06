// =============================================================================
// Move Subscription to Management Group
// =============================================================================
// Purpose: Associates an existing subscription with a target management group
// Scope: Management Group or Tenant Root
// API: Microsoft.Management/managementGroups/subscriptions@2023-04-01
// =============================================================================

targetScope = 'tenant'

@description('The subscription ID to move')
param subscriptionId string

@description('Target management group ID')
param targetManagementGroupId string

// =============================================================================
// Management Group Subscription Association
// =============================================================================
// Note: This resource places the subscription into the target MG hierarchy.
// The subscription name here is derived from the subscriptionId (last segment).
// Properties are read-only and managed by Azure.
// =============================================================================

resource mgSubscription 'Microsoft.Management/managementGroups/subscriptions@2023-04-01' = {
  name: '${targetManagementGroupId}/${subscriptionId}'
}

// =============================================================================
// Outputs
// =============================================================================

@description('The subscription ID that was moved')
output subscriptionId string = subscriptionId

@description('The target management group ID')
output managementGroupId string = targetManagementGroupId

@description('The fully qualified management group subscription resource ID')
output resourceId string = mgSubscription.id
