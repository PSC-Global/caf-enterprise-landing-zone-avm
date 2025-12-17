// ============================================================================
// Initiative: Asset Management - Require Core Tags
// Scope: Management Group (publish at MG scope for reuse)
// Effect: Audit (built-in policies remain in audit mode)
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-asset-management'
param displayName string = 'Asset Management - Core Tags Initiative'
param description string = 'Audits required tags (Environment, Owner, CostCenter) using built-in tag policies.'

// Built-in policy: Require a tag on resources
// ID: 871b6d14-10aa-478d-b590-94f262ecfa99
var requireTagPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99'

resource assetMgmtInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Asset Management'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'require-environment-tag'
        policyDefinitionId: requireTagPolicyId
        parameters: {
          tagName: {
            value: 'Environment'
          }
        }
      }
      {
        policyDefinitionReferenceId: 'require-owner-tag'
        policyDefinitionId: requireTagPolicyId
        parameters: {
          tagName: {
            value: 'Owner'
          }
        }
      }
      {
        policyDefinitionReferenceId: 'require-costcenter-tag'
        policyDefinitionId: requireTagPolicyId
        parameters: {
          tagName: {
            value: 'CostCenter'
          }
        }
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = assetMgmtInitiative.id
output policySetDefinitionName string = assetMgmtInitiative.name
