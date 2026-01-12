targetScope = 'managementGroup'

param initiativeName string = 'monitoring-baseline'
param displayName string = 'Logging & Monitoring Baseline'
param initiativeDescription string = 'Baseline monitoring guardrails using built-in policies.'
param category string = 'Logging & Monitoring'

@description('List of resource types to apply diagnostic settings.')
param listOfResourceTypes array = [
  'Microsoft.Compute/virtualMachines'
  'Microsoft.Storage/storageAccounts'
  'Microsoft.KeyVault/vaults'
  'Microsoft.Sql/servers/databases'
  'Microsoft.Network/azureFirewalls'
  'Microsoft.Network/virtualWans'
]

resource policySet 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: initiativeName
  properties: {
    policyType: 'Custom'
    displayName: displayName
    description: initiativeDescription
    metadata: {
      category: category
      version: '1.1.0'
      source: 'ASB: Logging & Monitoring'
    }
    parameters: {
      listOfResourceTypes: {
        type: 'Array'
        metadata: {
          displayName: 'Resource Types'
          description: 'List of resource types that should have diagnostic logs enabled'
        }
        defaultValue: listOfResourceTypes
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/7f89b1eb-583c-429a-8828-af049802c1d9'
        policyDefinitionReferenceId: 'ActivityLogRetention'
        groupNames: ['monitoring']
        parameters: {
          listOfResourceTypes: {
            value: '[parameters(\'listOfResourceTypes\')]'
          }
        }
      }
      // NOTE: Firewall diagnostics policy requires logAnalytics parameter (Log Analytics workspace ID)
      // This is a DeployIfNotExists policy that needs infrastructure-specific workspace ID
      // Uncomment and add logAnalytics parameter after configuring workspace ID
      // {
      //   policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/a4490248-cb97-4504-b7fb-f906afdb7437'
      //   policyDefinitionReferenceId: 'FirewallDiagnostics'
      //   groupNames: ['monitoring']
      //   parameters: {
      //     logAnalytics: {
      //       value: '<log-analytics-workspace-resource-id>' // Requires infrastructure-specific workspace ID
      //     }
      //   }
      // }
    ]
    policyDefinitionGroups: [
      {
        name: 'monitoring'
        displayName: 'Monitoring baseline'
        description: 'Policies enforcing logging and monitoring configurations, including vWAN and Firewall diagnostics'
      }
    ]
  }
}
