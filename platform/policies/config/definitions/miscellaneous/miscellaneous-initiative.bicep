// ============================================================================
// Initiative: Miscellaneous - Additional Compliance Controls
// Scope: Management Group
// Effect: Audit
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-miscellaneous'
param displayName string = 'Miscellaneous - Additional Compliance Initiative'
param description string = 'Audits additional compliance controls using built-in policies.'

var vmEncryptionPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-cb6b8b7818e8'

resource miscInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Miscellaneous'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'vm-disk-encryption'
        policyDefinitionId: vmEncryptionPolicyId
        parameters: {}
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = miscInitiative.id
output policySetDefinitionName string = miscInitiative.name
