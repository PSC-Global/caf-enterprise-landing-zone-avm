// ============================================================================
// Initiative: Identity - Access & Authentication
// Scope: Management Group
// Effect: Audit
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-identity'
param displayName string = 'Identity - Access & Authentication Initiative'
param description string = 'Audits identity and access controls using built-in policies.'

var mfaPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/e3576e28-8cb2-4677-88ff-8493023665b0'
var keyVaultPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/18adea5a-a3f6-4787-97f7-8b47f5741c98'

resource identityInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Identity'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'mfa-subscription'
        policyDefinitionId: mfaPolicyId
        parameters: {}
      }
      {
        policyDefinitionReferenceId: 'keyvault-purge-protection'
        policyDefinitionId: keyVaultPolicyId
        parameters: {}
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = identityInitiative.id
output policySetDefinitionName string = identityInitiative.name
