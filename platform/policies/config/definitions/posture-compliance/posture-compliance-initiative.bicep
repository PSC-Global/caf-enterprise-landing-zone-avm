// ============================================================================
// Initiative: Posture & Compliance - Vulnerability Assessment
// Scope: Management Group
// Effect: Audit
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-posture-compliance'
param displayName string = 'Posture & Compliance - Vulnerability Assessment Initiative'
param description string = 'Audits vulnerability assessment and compliance posture using built-in policies.'

var defenderPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/b7021b2b-08fd-4dc0-9de7-3c6ece09faf9'

resource postureInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Posture'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'defender-enabled'
        policyDefinitionId: defenderPolicyId
        parameters: {}
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = postureInitiative.id
output policySetDefinitionName string = postureInitiative.name
