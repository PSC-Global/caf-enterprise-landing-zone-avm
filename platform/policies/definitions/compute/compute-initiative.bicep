targetScope = 'managementGroup'

param initiativeName string = 'compute-baseline'
param displayName string = 'Compute Baseline'
param description string = 'Baseline compute security guardrails using built-in policies aligned with ASB Compute domain.'
param category string = 'Compute'

@allowed(['Audit', 'Deny', 'Disabled'])
param effect string = 'Audit'

// Some compute policies only support AuditIfNotExists/Disabled. Provide a dedicated parameter.
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
      source: 'ASB: Compute'
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
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-af6a37f2724d'
        policyDefinitionReferenceId: 'VMDiskEncryption'
        groupNames: ['compute']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/fc4d8e41-e223-45ea-9bf5-eada37891d87'
        policyDefinitionReferenceId: 'VMEncryptionAtHost'
        groupNames: ['compute']
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/1d84d5fb-01f6-4d12-ba4f-4a26081d403d'
        policyDefinitionReferenceId: 'MigrateToARM'
        groupNames: ['compute']
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'compute'
        displayName: 'Compute Security baseline'
        description: 'Policies enforcing VM encryption, secure configuration, and modern resource management'
      }
    ]
  }
}
