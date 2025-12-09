targetScope = 'subscription'

@description('List of all assignments from the pipeline')
param assignments array = []

@description('AAD group ID mapping: { groupName: objectId }')
param aadGroupIds object

// Load role name to GUID mapping
var roleDefinitionIds = loadJsonContent('role-definition-ids.json')

// Filter assignments to only subscription-scoped assignments for this subscription
var currentSubscriptionId = subscription().subscriptionId
var filteredAssignments = filter(assignments, item => item.scopeType == 'subscription' && item.scopeValue == currentSubscriptionId)

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for assignment in filteredAssignments: {
  name: guid(
    string(assignment.project),
    string(assignment.environment),
    string(assignment.aadGroupName),
    string(assignment.role)
  )
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      roleDefinitionIds[string(assignment.role)]
    )
    principalId: string(aadGroupIds[string(assignment.aadGroupName)])
    principalType: 'Group'
  }
}]
