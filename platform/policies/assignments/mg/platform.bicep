targetScope = 'managementGroup'

@description('Archetype name used in assignment naming.')
param archetypeName string

@description('Archetype configuration object with initiative parameter overrides.')
param archetype object

@description('Deployment location required for DINE policy assignments with managed identity.')
param location string = 'australiaeast'

@description('Management group ID containing the initiative definitions.')
param initiativeMgId string = 'rai'

var initiatives = items(archetype.initiatives)

resource assignments 'Microsoft.Authorization/policyAssignments@2023-04-01' = [for initiative in initiatives: {
  name: take('${archetypeName}-${initiative.key}', 24)
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: '${archetypeName} ${initiative.key}'
    policyDefinitionId: '/providers/Microsoft.Management/managementGroups/${initiativeMgId}/providers/Microsoft.Authorization/policySetDefinitions/${initiative.key}'
    parameters: reduce(items(initiative.value), {}, (current, param) => union(current, {
      '${param.key}': {
        value: param.value
      }
    }))
    enforcementMode: 'Default'
  }
}]
