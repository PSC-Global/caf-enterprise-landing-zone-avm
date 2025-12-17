// ============================================================================
// Initiative: Network - Security & Segmentation
// Scope: Management Group
// Effect: Audit
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-network'
param displayName string = 'Network - Security & Segmentation Initiative'
param description string = 'Audits network security and segmentation controls using built-in policies.'

var nsgPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dcf4b4d'
var rdpPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/e6955644-301c-44b5-a4c4-528577de6861'

resource networkInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Network'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'nsg-required'
        policyDefinitionId: nsgPolicyId
        parameters: {}
      }
      {
        policyDefinitionReferenceId: 'rdp-blocked'
        policyDefinitionId: rdpPolicyId
        parameters: {}
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = networkInitiative.id
output policySetDefinitionName string = networkInitiative.name
