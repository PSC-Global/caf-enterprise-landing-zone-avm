// =============================================================================
// Diagnostic Settings (Subscription Scope)
// =============================================================================
// Purpose: Enable diagnostic logging for subscription-level resources
// Scope: Subscription
// AVM: avm/res/insights/diagnostic-setting
// =============================================================================

targetScope = 'subscription'

// Note: Using subscription().id directly in the resource scope
// Parameter kept for future flexibility but currently unused

@description('Name of the diagnostic setting')
param diagnosticSettingName string = 'subscription-diagnostics'

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Storage account resource ID (optional)')
param storageAccountId string = ''

@description('Event Hub authorization rule resource ID (optional)')
param eventHubAuthorizationRuleId string = ''

@description('Event Hub name (optional)')
param eventHubName string = ''

@description('Enable all logs via categoryGroup')
param enableAllLogs bool = true

@description('Enable all metrics')
param enableAllMetrics bool = true

// =============================================================================
// Diagnostic Setting using Native Bicep
// =============================================================================
// Note: AVM diagnostic-setting module at 0.1.4 has incompatible API
// Using native Bicep for subscription-scope diagnostic settings

resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingName
  scope: subscription()
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: !empty(storageAccountId) ? storageAccountId : null
    eventHubAuthorizationRuleId: !empty(eventHubAuthorizationRuleId) ? eventHubAuthorizationRuleId : null
    eventHubName: !empty(eventHubName) ? eventHubName : null
    logs: enableAllLogs ? [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ] : []
    metrics: enableAllMetrics ? [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ] : []
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Diagnostic setting name')
output name string = diagnosticSetting.name

@description('Diagnostic setting resource ID')
output resourceId string = diagnosticSetting.id

