targetScope = 'managementGroup'

param initiativeName string = 'data-protection-baseline'
param displayName string = 'Data Protection Baseline'
param description string = 'Baseline data protection guardrails using built-in policies.'
param category string = 'Data Protection'

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
      source: 'ASB: Data Protection'
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
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/5752e6d6-1206-46d8-8ab1-ecc2f71a8112'
        policyDefinitionReferenceId: 'BackupVMsInstalled'
        groupNames: ['dataProtection']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/5752e6d6-1206-46d8-8ab1-ecc2f71a8112'
        policyDefinitionReferenceId: 'SecureProtocols'
        groupNames: ['dataProtection']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'dataProtection'
        displayName: 'Data Protection baseline'
        description: 'Policies enforcing data encryption in transit and at rest'
      }
    ]
  }
}
