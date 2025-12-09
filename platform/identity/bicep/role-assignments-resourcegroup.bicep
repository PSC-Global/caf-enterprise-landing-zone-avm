targetScope = 'resourceGroup'

@description('List of all assignments from the pipeline')
param assignments array = []

@description('AAD group ID mapping: { groupName: objectId }')
param aadGroupIds object

@description('Subscription ID used for filtering')
param subscriptionId string

@description('Resource group name used for filtering')
param resourceGroupName string

// Load role name to GUID mapping
var roleDefinitionIds = loadJsonContent('role-definition-ids.json')

// Filter assignments to only resourceGroup-scoped assignments for this specific RG
var filteredAssignments = filter(assignments, item => item.scopeType == 'resourceGroup' && item.scopeValue == subscriptionId && item.resourceGroup == resourceGroupName)

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for assignment in filteredAssignments: {
  name: guid(
    string(assignment.project),
    string(assignment.environment),
    string(assignment.aadGroupName),
    string(assignment.role)
  )
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      roleDefinitionIds[string(assignment.role)]
    )
    principalId: string(aadGroupIds[string(assignment.aadGroupName)])
    principalType: 'Group'
  }
}]
