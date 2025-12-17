// ============================================================================
// Initiative: Storage - Data Residency & Access
// Scope: Management Group
// Effect: Audit
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-storage'
param displayName string = 'Storage - Data Residency & Access Initiative'
param description string = 'Audits storage security and access controls using built-in policies.'

var httpsOnlyPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/6d555dd1-86f2-4f1c-8ed7-d64d490b2c67'

resource storageInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Storage'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'https-only'
        policyDefinitionId: httpsOnlyPolicyId
        parameters: {}
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = storageInitiative.id
output policySetDefinitionName string = storageInitiative.name
