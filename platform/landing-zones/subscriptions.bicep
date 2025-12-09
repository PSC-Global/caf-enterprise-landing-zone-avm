// =============================================================================
// SUBSCRIPTION CREATION - DEMO/TESTING ONLY
// =============================================================================
// Per Prompt.md Section 6 - Simplified demo approach
// - targetScope = 'tenant'  
// - Creates TWO subscriptions: lending-core-sub, fraud-engine-sub
// - Assigns to /landing-zones management group
// - Creates 3 RGs per subscription (dev, sit, prd)
//
// WARNING: Demo only - no billing, no EA/MCA, no AVM modules
// Production: use enterprise subscription vending
// =============================================================================

targetScope = 'tenant'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('Management group ID for landing zones')
param landingZonesMgId string = 'landing-zones'

// =============================================================================
// NOTE: Simplified Demo Implementation
// =============================================================================
// This file demonstrates the STRUCTURE required by Prompt.md Section 6
// Actual subscription creation requires:
// 1. Valid billing scope (EA enrollment or MCA billing profile)
// 2. Subscription alias API calls (not shown - requires Azure portal or CLI)
// 3. Management group association
// 4. Resource group creation at subscription scope
//
// For actual deployment, use Azure CLI:
//   az account alias create --name lending-core-sub --display-name "Lending Core" --workload Production
//   az account management-group subscription add --name landing-zones --subscription <sub-id>
// 
// Then deploy resource groups using resource-groups.bicep at subscription scope
// =============================================================================

// =============================================================================
// OUTPUTS (Placeholders for demonstration)
// =============================================================================

@description('Placeholder subscription ID for lending-core')
output lendingCoreSubscriptionId string = '<PLACEHOLDER-LENDING-SUB-ID>'

@description('Placeholder subscription ID for fraud-engine')
output fraudEngineSubscriptionId string = '<PLACEHOLDER-FRAUD-SUB-ID>'

@description('Resource groups to be created for lending-core')
output lendingCoreResourceGroups array = [
  'lending-core-dev-rg'
  'lending-core-sit-rg'
  'lending-core-prd-rg'
]

@description('Resource groups to be created for fraud-engine')
output fraudEngineResourceGroups array = [
  'fraud-engine-dev-rg'
  'fraud-engine-sit-rg'
  'fraud-engine-prd-rg'
]
