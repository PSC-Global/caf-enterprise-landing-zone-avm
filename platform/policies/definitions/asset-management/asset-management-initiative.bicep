targetScope = 'managementGroup'

@description('Name of the initiative (policy set definition).')
param initiativeName string = 'asset-management-baseline'

@description('Display name for the initiative.')
param displayName string = 'Asset Management Baseline'

@description('Description for the initiative.')
param initiativeDescription string = 'Baseline asset management guardrails using built-in policies.'

@description('ASB domain category.')
param category string = 'Asset Management'

@description('Effect parameter for policy enforcement.')
@allowed(['Audit', 'Deny', 'Disabled'])
param effect string = 'Audit'

resource policySet 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: initiativeName
  properties: {
    policyType: 'Custom'
    displayName: displayName
    description: initiativeDescription
    metadata: {
      category: category
      version: '1.0.0'
      source: 'ASB: Asset Management'
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
        policyDefinitionReferenceId: 'ClassicResourcesMigration'
        groupNames: ['assetManagement']
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/37e0d2fe-28a5-43d6-a273-67d37d1f5606'
        policyDefinitionReferenceId: 'ClassicStorageMigration'
        groupNames: ['assetManagement']
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'assetManagement'
        displayName: 'Asset management baseline'
        description: 'Policies enforcing asset tagging, inventory, and lifecycle management'
      }
    ]
  }
}
