// ============================================================================
// Built-In Policy Assignment: Require Tag on Resources (Corp)
// Scope: Management Group (rai-corp)
// Enforcement: Audit-only (DoNotEnforce)
// ============================================================================

targetScope = 'managementGroup'

param policyDefinitionId string
param assignmentName string
param displayName string
param assignmentDescription string
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string
param location string
param enableManagedIdentity bool
param policyParameters object
param nonComplianceMessages array

module tagAssignment '../../../../modules/policy-assignment-mg.bicep' = {
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

output assignmentId string = tagAssignment.outputs.assignmentId
output assignmentNameOut string = tagAssignment.outputs.assignmentName
output enforcementModeOut string = tagAssignment.outputs.enforcementMode
