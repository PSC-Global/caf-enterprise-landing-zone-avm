// ============================================================================
// Initiative: Compute - Allowed VM SKUs
// Scope: Management Group (publish at MG scope for reuse)
// Effect: Audit (assignment will set DoNotEnforce)
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-compute'
param displayName string = 'Compute - Allowed VM SKUs Initiative'
param description string = 'Audits virtual machines not in the allowed SKU list using built-in policy.'

// Built-in policy: Allowed virtual machine SKUs
// ID: 0a15ec92-8c05-49b8-9016-83adb18aa6c9
var allowedVmSkusPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/0a15ec92-8c05-49b8-9016-83adb18aa6c9'

resource computeInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Compute'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'allowed-vm-skus'
        policyDefinitionId: allowedVmSkusPolicyId
        parameters: {
          listOfAllowedSKUs: {
            value: [
              'Standard_DS2_v2'
              'Standard_DS3_v2'
              'Standard_D4s_v5'
              'Standard_D8s_v5'
              'Standard_E4s_v5'
              'Standard_E8s_v5'
            ]
          }
        }
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = computeInitiative.id
output policySetDefinitionName string = computeInitiative.name
