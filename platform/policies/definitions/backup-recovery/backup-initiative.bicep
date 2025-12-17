targetScope = 'managementGroup'

param initiativeName string = 'backup-baseline'
param displayName string = 'Backup & Recovery Baseline'
param description string = 'Baseline backup guardrails using built-in policies.'
param category string = 'Backup & Recovery'

@allowed(['AuditIfNotExists', 'DeployIfNotExists', 'Disabled'])
param effect string = 'AuditIfNotExists'

resource policySet 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: initiativeName
  properties: {
    policyType: 'Custom'
    displayName: displayName
    description: description
    metadata: {
      category: category
      version: '1.0.0'
      source: 'ASB: Backup & Recovery'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policies'
        }
        allowedValues: ['AuditIfNotExists', 'DeployIfNotExists', 'Disabled']
        defaultValue: effect
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/013e242c-8828-4970-87b3-ab247555486d'
        policyDefinitionReferenceId: 'VMBackupEnabled'
        groupNames: ['backupRecovery']
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'backupRecovery'
        displayName: 'Backup & Recovery baseline'
        description: 'Policies enforcing Azure Backup for VMs and data protection'
      }
    ]
  }
}
