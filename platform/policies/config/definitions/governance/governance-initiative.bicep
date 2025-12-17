// ============================================================================
// Initiative: Governance - Location & Allowed Services
// Scope: Management Group (publish at MG scope for reuse)
// Effect: Audit (assignments stay DoNotEnforce; enforcement in later phases)
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-governance'
param displayName string = 'Governance - Location & Allowed Services Initiative'
param description string = 'Audits resource locations and allowed services to enforce data residency and organizational standards using built-in policies.'

// Built-in policy IDs
// Allowed locations (configured per assignment)
var allowedLocationsPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-f8dc52de7221'
// Allowed resource types (configured per assignment)
var allowedResourceTypesPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/a08f37ab-19e9-468e-a74f-3626d7897e27'

resource governanceInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Governance'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'allowed-locations'
        policyDefinitionId: allowedLocationsPolicyId
        parameters: {
          listOfAllowedLocations: {
            value: [
              'australiaeast'
              'australiasoutheast'
            ]
          }
        }
      }
      {
        policyDefinitionReferenceId: 'allowed-resource-types'
        policyDefinitionId: allowedResourceTypesPolicyId
        parameters: {
          listOfResourceTypesAllowed: {
            value: [
              'Microsoft.Compute/virtualMachines'
              'Microsoft.Storage/storageAccounts'
              'Microsoft.Network/virtualNetworks'
              'Microsoft.KeyVault/vaults'
              'Microsoft.SQL/servers'
              'Microsoft.Insights/components'
              'Microsoft.ContainerRegistry/registries'
              'Microsoft.ContainerService/managedClusters'
            ]
          }
        }
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = governanceInitiative.id
output policySetDefinitionName string = governanceInitiative.name
