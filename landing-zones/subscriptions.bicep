// Moved from platform/landing-zones/subscriptions.bicep
// See platform/docs for usage notes.

targetScope = 'tenant'

@description('Management group ID for landing zones')
param landingZonesMgId string = 'landing-zones'

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
