// ============================================================================
// Assignment: Logging & Monitoring Initiative (Corp)
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

module initiativeAssignment '../../../../modules/policy-assignment-mg.bicep' = {
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

output assignmentId string = initiativeAssignment.outputs.assignmentId
output assignmentNameOut string = initiativeAssignment.outputs.assignmentName
output enforcementModeOut string = initiativeAssignment.outputs.enforcementMode
