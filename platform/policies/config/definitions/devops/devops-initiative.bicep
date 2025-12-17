// ============================================================================
// Initiative: DevOps - Container Registry & Artifacts Security
// Scope: Management Group (publish at MG scope for reuse)
// Effect: Audit (assignments stay DoNotEnforce)
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-devops'
param displayName string = 'DevOps - Container Registry Security Initiative'
param description string = 'Audits container registries and artifacts for security best practices using built-in policies.'

// Built-in policy IDs
// Container registries should use managed identities
var managedIdentityPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/9f2a546f-fa04-4ef5-8169-d1e8e14b3bcc'
// Azure Container Registry repositories should be private
var privateRegistryPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/e16da7ba-883d-4615-adeq-1ee808e59059'

resource devopsInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'DevOps'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'acr-managed-identity'
        policyDefinitionId: managedIdentityPolicyId
        parameters: {}
      }
      {
        policyDefinitionReferenceId: 'acr-private'
        policyDefinitionId: privateRegistryPolicyId
        parameters: {}
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = devopsInitiative.id
output policySetDefinitionName string = devopsInitiative.name
