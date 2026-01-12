// =============================================================================
// Action Groups
// =============================================================================
// Purpose: Creates Azure Monitor Action Groups for alerting
// Scope: Resource Group
// Note: Using native Bicep - AVM module for action groups is not available
//       in the public registry (br/public:avm/res/monitor/action-group)
// Contract: Follows platform/shared/contract.bicep standards
// =============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Standard Platform Parameters (from platform/shared/contract.bicep)
// -----------------------------------------------------------------------------

@description('Deployment environment')
param environment string = 'prod'

@description('Azure region for resource deployment (not used but kept for contract compliance)')
param location string = 'australiaeast'

@description('Tags to apply to all resources')
param tags object

// -----------------------------------------------------------------------------
// Module-Specific Parameters
// -----------------------------------------------------------------------------

@description('Array of action group configurations')
param actionGroupConfigs array = []

// Action Group structure:
// {
//   "name": "ag-rai-prod-aue-platform-critical",
//   "shortName": "platform-crit",
//   "enabled": true,
//   "emailReceivers": [
//     {
//       "name": "PlatformTeam",
//       "emailAddress": "platform-team@example.com",
//       "useCommonAlertSchema": true
//     }
//   ],
//   "smsReceivers": [],
//   "webhookReceivers": [],
//   "azureAppPushReceivers": [],
//   "itsmReceivers": [],
//   "automationRunbookReceivers": [],
//   "voiceReceivers": [],
//   "logicAppReceivers": [],
//   "azureFunctionReceivers": [],
//   "armRoleReceivers": [],
//   "eventHubReceivers": []
// }

// =============================================================================
// Action Groups using native Bicep
// =============================================================================
// Note: AVM module for action groups is not available in public registry.
//       Using native Bicep resource definition following Azure best practices.

resource actionGroups 'Microsoft.Insights/actionGroups@2023-01-01' = [for ag in actionGroupConfigs: {
  name: ag.name
  location: 'Global' // Action groups are always Global, location param not used
  tags: union(tags, {
    purpose: 'alerting'
    actionGroupType: ag.type ?? 'general'
    environment: environment
  })
  properties: {
    groupShortName: ag.shortName
    enabled: ag.enabled
    emailReceivers: ag.emailReceivers ?? []
    smsReceivers: ag.smsReceivers ?? []
    webhookReceivers: ag.webhookReceivers ?? []
    azureAppPushReceivers: ag.azureAppPushReceivers ?? []
    itsmReceivers: ag.itsmReceivers ?? []
    automationRunbookReceivers: ag.automationRunbookReceivers ?? []
    voiceReceivers: ag.voiceReceivers ?? []
    logicAppReceivers: ag.logicAppReceivers ?? []
    azureFunctionReceivers: ag.azureFunctionReceivers ?? []
    armRoleReceivers: ag.armRoleReceivers ?? []
    eventHubReceivers: ag.eventHubReceivers ?? []
  }
}]

// =============================================================================
// Outputs
// =============================================================================

@description('Action group resource IDs')
output actionGroupResourceIds array = [for (ag, i) in actionGroupConfigs: {
  name: ag.name
  resourceId: actionGroups[i].id
}]

@description('Action group names')
output actionGroupNames array = [for ag in actionGroupConfigs: ag.name]
