// =============================================================================
// Diagnostic Settings
// =============================================================================
// Purpose: Enable diagnostic logging for subscription resources
// Scope: Resource Group
// AVM: avm/res/insights/diagnostic-setting
// =============================================================================

targetScope = 'resourceGroup'

@description('Resource ID of the resource to enable diagnostics for')
param targetResourceId string

@description('Name of the diagnostic setting')
param diagnosticSettingName string = 'default-diagnostics'

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Storage account resource ID (optional)')
param storageAccountId string = ''

@description('Event Hub authorization rule resource ID (optional)')
param eventHubAuthorizationRuleId string = ''

@description('Event Hub name (optional)')
param eventHubName string = ''

@description('Log categories to enable (empty array = all logs)')
param logCategories array = []

@description('Metric categories to enable (empty array = all metrics)')
param metricCategories array = []

@description('Enable all logs via categoryGroup')
param enableAllLogs bool = true

@description('Enable all metrics')
param enableAllMetrics bool = true

// =============================================================================
// Diagnostic Setting using AVM
// =============================================================================

module diagnosticSetting 'br/public:avm/res/insights/diagnostic-setting:0.1.4' = {
  name: 'diag-${uniqueString(targetResourceId)}'
  scope: resourceGroup()
  params: {
    name: diagnosticSettingName
    resourceId: targetResourceId
    workspaceResourceId: logAnalyticsWorkspaceId
    storageAccountResourceId: !empty(storageAccountId) ? storageAccountId : null
    eventHubAuthorizationRuleResourceId: !empty(eventHubAuthorizationRuleId) ? eventHubAuthorizationRuleId : null
    eventHubName: !empty(eventHubName) ? eventHubName : null
    logCategoriesAndGroups: enableAllLogs ? [
      {
        categoryGroup: 'allLogs'
      }
    ] : [for category in logCategories: {
      category: category
      enabled: true
    }]
    metricCategories: enableAllMetrics ? [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ] : [for metric in metricCategories: {
      category: metric
      enabled: true
    }]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Diagnostic setting name')
output name string = diagnosticSetting.outputs.name

@description('Diagnostic setting resource ID')
output resourceId string = diagnosticSetting.outputs.resourceId
