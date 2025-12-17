targetScope = 'managementGroup'

param initiativeName string = 'defender-baseline'
param displayName string = 'Posture & Compliance (Defender) Baseline'
param description string = 'Baseline posture/compliance guardrails using built-in policies.'
param category string = 'Posture & Compliance'

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
      source: 'ASB: Posture & Compliance'
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
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/013e242c-8828-4970-87b3-ab247555486d'
        policyDefinitionReferenceId: 'AzureBackupVMs'
        groupNames: ['defender']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'defender'
        displayName: 'Defender baseline'
        description: 'Policies enforcing Microsoft Defender for Cloud and compliance posture'
      }
    ]
  }
}
