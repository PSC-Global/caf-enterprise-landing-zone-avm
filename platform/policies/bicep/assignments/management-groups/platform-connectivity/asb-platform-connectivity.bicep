// ============================================================================
// Azure Security Benchmark - Platform Connectivity Assignment
// ============================================================================
// Description: Assigns Azure Security Benchmark v3 to Platform Connectivity MG
// Scope: Management Group (rai-platform-connectivity)
// Enforcement: Audit-only (DoNotEnforce) - phased enforcement in future
// ============================================================================

targetScope = 'managementGroup'

// ============================================================================
// PARAMETERS - Loaded from parameter file
// ============================================================================

@description('The resource ID of the policy definition or initiative to assign')
param policyDefinitionId string

@description('The name of the policy assignment')
param assignmentName string

@description('The display name for the policy assignment')
param displayName string

@description('The description for the policy assignment')
param assignmentDescription string

@description('The enforcement mode for the policy assignment')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string

@description('The location for the policy assignment metadata')
param location string

@description('Whether to enable system-assigned managed identity')
param enableManagedIdentity bool

@description('Parameters for the policy assignment')
param policyParameters object

@description('Non-compliance messages for the policy assignment')
param nonComplianceMessages array

// ============================================================================
// RESOURCES
// ============================================================================

// Azure Security Benchmark assignment to Platform Connectivity MG using reusable module
module asbPlatformConnectivityAssignment '../../../modules/policy-assignment-mg.bicep' = {
  name: 'deploy-${assignmentName}'
  params: {
    policyDefinitionId: policyDefinitionId
    assignmentName: assignmentName
    displayName: displayName
    assignmentDescription: assignmentDescription
    enforcementMode: enforcementMode
    location: location
    enableManagedIdentity: enableManagedIdentity
    policyParameters: policyParameters
    nonComplianceMessages: nonComplianceMessages
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('The resource ID of the ASB platform connectivity assignment')
output assignmentId string = asbPlatformConnectivityAssignment.outputs.assignmentId

@description('The name of the ASB platform connectivity assignment')
output assignmentName string = asbPlatformConnectivityAssignment.outputs.assignmentName

@description('The enforcement mode of the ASB platform connectivity assignment')
output enforcementMode string = asbPlatformConnectivityAssignment.outputs.enforcementMode
