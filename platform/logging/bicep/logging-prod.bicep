// =============================================================================
// Central Logging Backbone - Production
// =============================================================================
// Purpose: Orchestrates deployment of central logging infrastructure
//          - Resource Group
//          - Log Analytics Workspace
//          - Action Groups
// Scope: Subscription
// Contract: Follows platform/shared/contract.bicep standards
// =============================================================================

targetScope = 'subscription'

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

@description('Log Analytics Workspace name')
param logAnalyticsWorkspaceName string

@description('Resource group name (optional, will be generated if not provided)')
param resourceGroupName string = ''

@description('Data retention in days for Log Analytics Workspace')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('SKU name for Log Analytics Workspace')
@allowed([
  'PerGB2018'
  'CapacityReservation'
])
param skuName string = 'PerGB2018'

@description('Daily quota in GB for Log Analytics Workspace (-1 for unlimited)')
param dailyQuotaGb int = -1

@description('Enable diagnostic settings for the workspace itself')
param enableWorkspaceDiagnostics bool = false

@description('Diagnostic storage account resource ID (if enableWorkspaceDiagnostics is true)')
param diagnosticStorageAccountId string = ''

@description('Array of action group configurations')
param actionGroupConfigs array = []

// =============================================================================
// Resource Group Name (calculated upfront)
// =============================================================================

var calculatedRgName = !empty(resourceGroupName) ? resourceGroupName : 'rg-rai-${environment}-${location}-logging-001'

// =============================================================================
// Phase 1: Create Resource Group
// =============================================================================

module resourceGroup './resource-group.bicep' = {
  name: 'rg-logging-${uniqueString(deployment().name)}'
  params: {
    environment: environment
    location: location
    tags: tags
    resourceGroupName: calculatedRgName
  }
}

// =============================================================================
// Phase 2 & 3: Log Analytics Workspace and Action Groups
// =============================================================================
// Note: These resources are deployed via separate az deployment group create
// commands in deploy-logging.ps1 script after the resource group is created.
// This is because Bicep doesn't support scoping modules to resource groups
// from subscription scope in this version.
// =============================================================================
// The script will:
// 1. Deploy this file (creates resource group only)
// 2. Deploy log-analytics-workspace.bicep at resource group scope
// 3. Deploy action-groups.bicep at resource group scope (if configured)
// =============================================================================

// =============================================================================
// Outputs
// =============================================================================
// Standard outputs following platform/shared/contract.bicep naming conventions
// These outputs are consumed by downstream phases

@description('Log Analytics Workspace resource ID (standard output for downstream phases). Note: This will be populated by deploy-logging.ps1 script after LAW deployment')
output logAnalyticsWorkspaceResourceId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${calculatedRgName}/providers/Microsoft.OperationalInsights/workspaces/${logAnalyticsWorkspaceName}'

@description('Log Analytics Workspace name (standard output for downstream phases)')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspaceName

@description('Log Analytics Workspace ID (for linking to resources). Note: This will be populated by deploy-logging.ps1 script after LAW deployment')
output workspaceId string = '' // Will be populated by script

@description('Resource group name')
output resourceGroupName string = resourceGroup.outputs.resourceGroupName

@description('Resource group resource ID')
output resourceGroupResourceId string = resourceGroup.outputs.resourceGroupResourceId

@description('Action group resource IDs (if action groups were deployed). Note: This will be populated by deploy-logging.ps1 script after action groups deployment')
output actionGroupResourceIds array = []

@description('Action group names (if action groups were deployed). Note: This will be populated by deploy-logging.ps1 script after action groups deployment')
var actionGroupNamesArray = [for ag in actionGroupConfigs: ag.name]
output actionGroupNames array = actionGroupNamesArray
