// ============================================================================
// Initiative: Data Protection - Storage Encryption & Access
// Scope: Management Group (publish at MG scope for reuse)
// Effect: Audit (assignments stay DoNotEnforce)
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-data-protection'
param displayName string = 'Data Protection - Storage Encryption & Access Initiative'
param description string = 'Audits storage accounts for secure transfer and public access posture using built-in policies.'

// Built-in policy IDs
// Secure transfer to storage accounts should be enabled
var secureTransferPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/20e53a74-8511-4fd3-bf76-4f48faffb2f6'
// Public network access on storage accounts should be disabled
var publicAccessPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/8933573a-141c-4fea-8217-22317b86a4e0'

resource dataProtectionInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Data Protection'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'secure-transfer'
        policyDefinitionId: secureTransferPolicyId
        parameters: {}
      }
      {
        policyDefinitionReferenceId: 'public-access'
        policyDefinitionId: publicAccessPolicyId
        parameters: {}
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = dataProtectionInitiative.id
output policySetDefinitionName string = dataProtectionInitiative.name
