targetScope = 'managementGroup'

param initiativeName string = 'misc-baseline'
param displayName string = 'Miscellaneous Baseline'
param description string = 'Baseline miscellaneous guardrails using built-in policies.'
param category string = 'Miscellaneous'

@allowed(['AuditIfNotExists', 'Disabled'])
param auditIfNotExistsEffect string = 'AuditIfNotExists'

resource policySet 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: initiativeName
  properties: {
    policyType: 'Custom'
    displayName: displayName
    description: description
    metadata: {
      category: category
      version: '1.0.0'
      source: 'ASB: Miscellaneous'
    }
    parameters: {
      auditIfNotExistsEffect: {
        type: 'String'
        metadata: {
          displayName: 'AuditIfNotExists Effect'
          description: 'Effect for policies that support AuditIfNotExists/Disabled only'
        }
        allowedValues: ['AuditIfNotExists', 'Disabled']
        defaultValue: auditIfNotExistsEffect
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/88999f4c-376a-45c8-bcb3-4058f713cf39'
        policyDefinitionReferenceId: 'AllowedLocations'
        groupNames: ['misc']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'misc'
        displayName: 'Misc baseline'
        description: 'Miscellaneous security policies'
      }
    ]
  }
}
