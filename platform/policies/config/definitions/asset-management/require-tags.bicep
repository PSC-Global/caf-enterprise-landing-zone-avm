// ============================================================================
// Policy Definition: Require Tags on Resources (Asset Management)
// Scope: Management Group (publish definition at MG scope)
// Effect: Audit (enforcement deferred)
// ============================================================================

targetScope = 'managementGroup'

param policyDefinitionName string = 'rai-require-tags'
param displayName string = 'Require mandatory tags on resources'
param policyDescription string = 'Audits resources missing required tags to improve asset management and ownership tracking.'
param requiredTagNames array = [
  'Environment'
  'Owner'
  'CostCenter'
]

resource policyDef 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: policyDefinitionName
  properties: {
    displayName: displayName
    description: policyDescription
    mode: 'Indexed'
    policyType: 'Custom'
    metadata: {
      category: 'Asset Management'
      version: '1.0.0'
    }
    parameters: {
      requiredTagNames: {
        type: 'Array'
        metadata: {
          displayName: 'Required tag names'
          description: 'List of tag names that must exist on resources.'
        }
        defaultValue: requiredTagNames
      }
    }
    policyRule: {
      if: {
        anyOf: [
          {
            allOf: [
              {
                field: 'type'
                notEquals: 'Microsoft.ResourceGraph/queries'
              }
              {
                field: 'tags'
                exists: false
              }
            ]
          }
          {
            anyOf: [for tagName in requiredTagNames: {
              field: 'tags[${tagName}]'
              exists: false
            }]
          }
        ]
      }
      then: {
        effect: 'audit'
      }
    }
  }
}

output policyDefinitionId string = policyDef.id
