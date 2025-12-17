targetScope = 'managementGroup'

@description('Name of the initiative (policy set definition).')
param initiativeName string = 'identity-baseline'

@description('Display name for the initiative.')
param displayName string = 'Identity Baseline'

@description('Description for the initiative.')
param initiativeDescription string = 'Baseline identity guardrails using built-in policies aligned with ASB Identity Management domain.'

@description('ASB domain category.')
param category string = 'Identity'

@description('Effect for policies that only support AuditIfNotExists/Disabled.')
@allowed(['AuditIfNotExists', 'Disabled'])
param auditIfNotExistsEffect string = 'AuditIfNotExists'

resource policySet 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: initiativeName
  properties: {
    policyType: 'Custom'
    displayName: displayName
    description: initiativeDescription
    metadata: {
      category: category
      version: '1.0.0'
      source: 'ASB: Identity Management'
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
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/2b9ad585-36bc-4615-b300-fd4435808332'
        policyDefinitionReferenceId: 'AppServiceUseManagedIdentity'
        groupNames: ['identity']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/0da106f2-4ca3-48e8-bc85-c638fe6aea8f'
        policyDefinitionReferenceId: 'FunctionAppUseManagedIdentity'
        groupNames: ['identity']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/d26f7642-7545-4e18-9b75-8c9bbdee3a9a'
        policyDefinitionReferenceId: 'VMGuestConfigUseManagedIdentity'
        groupNames: ['identity']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'identity'
        displayName: 'Identity Management baseline'
        description: 'Policies enforcing use of managed identities and centralized authentication'
      }
    ]
  }
}
