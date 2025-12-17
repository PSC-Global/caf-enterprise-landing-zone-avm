// ============================================================================
// Policy Assignment Module - Management Group Scope
// ============================================================================
// Description: Reusable wrapper for AVM policy assignment at management group scope
// Usage: Assign built-in or custom policies/initiatives to management groups
// ============================================================================

targetScope = 'managementGroup'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('The resource ID of the policy definition or initiative to assign')
param policyDefinitionId string

@description('The name of the policy assignment (must be unique within the scope)')
param assignmentName string

@description('The display name for the policy assignment')
param displayName string = ''

@description('The description for the policy assignment')
param assignmentDescription string = ''

@description('The enforcement mode for the policy assignment. Use DoNotEnforce for audit-only mode.')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'DoNotEnforce'

@description('The location for the policy assignment metadata. Required for management group deployments.')
param location string = 'australiaeast'

@description('Parameters for the policy assignment as a JSON object')
param policyParameters object = {}

@description('Whether to enable system-assigned managed identity for remediation tasks (DeployIfNotExists/Modify policies)')
param enableManagedIdentity bool = false

// Note: roleDefinitionIds parameter will be added in enforcement phase for managed identity RBAC

@description('Non-compliance messages for the policy assignment')
param nonComplianceMessages array = []

// ============================================================================
// RESOURCES
// ============================================================================

// Policy Assignment using AVM pattern
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: assignmentName
  location: location
  identity: enableManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    displayName: !empty(displayName) ? displayName : assignmentName
    description: assignmentDescription
    policyDefinitionId: policyDefinitionId
    enforcementMode: enforcementMode
    parameters: !empty(policyParameters) ? policyParameters : null
    nonComplianceMessages: !empty(nonComplianceMessages) ? nonComplianceMessages : null
  }
}

// Role assignments for managed identity (if enabled)
// Note: Deferred to enforcement phase - not implemented in audit-only mode
// Future implementation will use nested deployments at subscription scope for RBAC

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The resource ID of the policy assignment')
output assignmentId string = policyAssignment.id

@description('The name of the policy assignment')
output assignmentName string = policyAssignment.name

@description('The principal ID of the system-assigned managed identity (if enabled)')
output principalId string = enableManagedIdentity ? policyAssignment.identity.principalId : ''

@description('The enforcement mode of the policy assignment')
output enforcementMode string = policyAssignment.properties.enforcementMode
