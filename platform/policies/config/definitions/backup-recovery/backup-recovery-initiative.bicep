// ============================================================================
// Initiative: Backup & Recovery - Core Controls
// Scope: Management Group (publish at MG scope for reuse)
// Effect: Audit (built-in policies are audit by default; change assignments to enforce later)
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-backup-recovery'
param displayName string = 'Backup & Recovery - Core Initiative'
param description string = 'Audits VM and SQL backups using built-in policies.'

// Built-in policy IDs (commonly used backup policies)
// Require backup on VMs: 3fcf8816-6d0b-447a-8cfc-6a1c9b0e827f
// Configure backup on SQL servers in VMs: fc5c4771-04a8-4ad0-9b98-37e9eb65f9b5
var vmBackupPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/3fcf8816-6d0b-447a-8cfc-6a1c9b0e827f'
var sqlVmBackupPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/fc5c4771-04a8-4ad0-9b98-37e9eb65f9b5'

resource backupInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Backup'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'vm-backup'
        policyDefinitionId: vmBackupPolicyId
        parameters: {}
      }
      {
        policyDefinitionReferenceId: 'sql-vm-backup'
        policyDefinitionId: sqlVmBackupPolicyId
        parameters: {}
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = backupInitiative.id
output policySetDefinitionName string = backupInitiative.name
