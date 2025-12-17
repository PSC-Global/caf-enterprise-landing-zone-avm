targetScope = 'managementGroup'

param initiativeName string = 'governance-baseline'
param displayName string = 'Governance Baseline'
param description string = 'Baseline governance guardrails using built-in policies.'
param category string = 'Governance'

@allowed(['Audit', 'Deny', 'Disabled'])
param effect string = 'Audit'

resource policySet 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: initiativeName
  properties: {
    policyType: 'Custom'
    displayName: displayName
    description: description
    metadata: {
      category: category
      version: '1.0.0'
      source: 'ASB: Governance'
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
    }
    policyDefinitions: [
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/1d84d5fb-01f6-4d12-ba4f-4a26081d403d'
        policyDefinitionReferenceId: 'MigrateVMToARM'
        groupNames: ['governance']
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'governance'
        displayName: 'Governance baseline'
        description: 'Policies enforcing governance standards and resource management'
      }
    ]
  }
}
