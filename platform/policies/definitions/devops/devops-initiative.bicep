targetScope = 'managementGroup'

param initiativeName string = 'devops-baseline'
param displayName string = 'DevOps Baseline'
param description string = 'Baseline DevOps guardrails using built-in policies.'
param category string = 'DevOps'

@allowed(['Audit', 'Deny', 'Disabled'])
param effect string = 'Audit'

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
      source: 'ASB: DevOps'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policies'
        }
        allowedValues: ['Audit', 'Deny', 'Disabled']
        defaultValue: effect
      }
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
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/5f0f936f-2f01-4bf5-b6be-d423792fa562'
        policyDefinitionReferenceId: 'ContainerRegistryPrivateEndpoint'
        groupNames: ['devOps']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/0fdf0491-d080-4575-b627-ad0e843cba0f'
        policyDefinitionReferenceId: 'ContainerRegistrySKU'
        groupNames: ['devOps']
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'devOps'
        displayName: 'DevOps baseline'
        description: 'Policies enforcing DevOps security practices'
      }
    ]
  }
}
