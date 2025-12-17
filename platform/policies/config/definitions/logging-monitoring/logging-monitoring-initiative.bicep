// ============================================================================
// Initiative: Logging & Monitoring - Diagnostics & Alerting
// Scope: Management Group
// Effect: Audit
// ============================================================================

targetScope = 'managementGroup'

param policySetName string = 'rai-logging-monitoring'
param displayName string = 'Logging & Monitoring - Diagnostics Initiative'
param description string = 'Audits diagnostic settings and monitoring compliance using built-in policies.'

var diagnosticsPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/b145dd17-e4ea-4b67-b0c5-3ccc1e6252ab'

resource loggingInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: policySetName
  properties: {
    displayName: displayName
    description: description
    policyType: 'Custom'
    metadata: {
      category: 'Logging'
      version: '1.0.0'
    }
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'diagnostic-settings'
        policyDefinitionId: diagnosticsPolicyId
        parameters: {}
      }
    ]
    parameters: {}
  }
}

output policySetDefinitionId string = loggingInitiative.id
output policySetDefinitionName string = loggingInitiative.name
