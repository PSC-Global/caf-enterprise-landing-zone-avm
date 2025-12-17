targetScope = 'subscription'

@description('Name of the compliance framework')
param complianceFramework string

@description('Built-in policy set definition ID for the compliance framework')
param policySetDefinitionId string

@description('Assignment name')
param assignmentName string = '${complianceFramework}-compliance'

@description('Assignment display name')
param displayName string

@description('Location for managed identity (required for DeployIfNotExists policies)')
param location string = 'australiaeast'

@description('Enforcement mode - DoNotEnforce for audit-only')
@allowed(['Default', 'DoNotEnforce'])
param enforcementMode string = 'DoNotEnforce'

resource complianceAssignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: assignmentName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: displayName
    description: 'Regulatory compliance assignment for ${complianceFramework} - audit only, for compliance reporting'
    enforcementMode: enforcementMode
    policyDefinitionId: policySetDefinitionId
    metadata: {
      category: 'Regulatory Compliance'
      framework: complianceFramework
      assignedBy: 'Platform Governance'
    }
  }
}

// Role assignment for managed identity (required for remediation)
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, complianceAssignment.id, 'Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: complianceAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output assignmentId string = complianceAssignment.id
output assignmentName string = complianceAssignment.name
output identityPrincipalId string = complianceAssignment.identity.principalId
