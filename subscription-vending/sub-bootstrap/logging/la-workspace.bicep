// =============================================================================
// Log Analytics Workspace
// =============================================================================
// Purpose: Creates a Log Analytics workspace for diagnostics and monitoring
// Scope: Resource Group
// AVM: avm/res/operational-insights/workspace
// Contract: Follows platform/shared/contract.bicep standards
// =============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Standard Platform Parameters (from platform/shared/contract.bicep)
// -----------------------------------------------------------------------------

@description('Deployment environment')
param environment string = 'prod'

@description('Azure region for resource deployment')
param location string

@description('Tags to apply to all resources')
param tags object

// -----------------------------------------------------------------------------
// Module-Specific Parameters
// -----------------------------------------------------------------------------

@description('Workspace name')
param workspaceName string

@description('Data retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('SKU name')
@allowed([
  'PerGB2018'
  'CapacityReservation'
])
param skuName string = 'PerGB2018'

@description('Daily quota in GB (-1 for unlimited)')
param dailyQuotaGb int = -1

@description('Enable diagnostic settings')
param enableDiagnostics bool = false

@description('Diagnostic storage account resource ID')
param diagnosticStorageAccountId string = ''

// =============================================================================
// Log Analytics Workspace using AVM
// =============================================================================

module workspace 'br/public:avm/res/operational-insights/workspace:0.9.1' = {
  name: 'law-${uniqueString(resourceGroup().id)}'
  params: {
    name: workspaceName
    location: location
    tags: tags
    skuName: skuName
    dataRetention: retentionInDays
    dailyQuotaGb: dailyQuotaGb
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    diagnosticSettings: enableDiagnostics && !empty(diagnosticStorageAccountId) ? [
      {
        name: 'law-diagnostics'
        storageAccountResourceId: diagnosticStorageAccountId
        logCategoriesAndGroups: [
          {
            categoryGroup: 'allLogs'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
      }
    ] : []
  }
}

// =============================================================================
// Outputs
// =============================================================================
// Standard outputs following platform/shared/contract.bicep naming conventions

@description('Log Analytics workspace name')
output name string = workspace.outputs.name

@description('Log Analytics Workspace resource ID (standard output)')
output logAnalyticsWorkspaceResourceId string = workspace.outputs.resourceId

@description('Log Analytics workspace ID (for linking to resources)')
output workspaceId string = workspace.outputs.logAnalyticsWorkspaceId

@description('Location')
output location string = location

// Legacy output names (deprecated - use standard names above)
@description('DEPRECATED: Use logAnalyticsWorkspaceResourceId instead')
output resourceId string = workspace.outputs.resourceId
