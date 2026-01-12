// =============================================================================
// Application Gateway with WAF v2
// =============================================================================
// Purpose: Deploys Application Gateway with Web Application Firewall for ingress
// Scope: Resource Group
// AVM: avm/res/network/application-gateway, avm/res/network/application-gateway-web-application-firewall-policy
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

@description('Log Analytics Workspace resource ID for diagnostics')
param logAnalyticsWorkspaceResourceId string = ''

// -----------------------------------------------------------------------------
// Module-Specific Parameters
// -----------------------------------------------------------------------------

@description('Application Gateway name')
param applicationGatewayName string

@description('Application Gateway subnet resource ID')
param subnetResourceId string

@description('Public IP address name (optional, auto-generated if not provided)')
param publicIpName string = ''

@description('WAF Policy resource ID (optional, will create if not provided)')
param wafPolicyResourceId string = ''

@description('Application Gateway SKU')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param skuName string = 'WAF_v2'

@description('Application Gateway tier')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param skuTier string = 'WAF_v2'

@description('Application Gateway capacity (autoscaling min instances)')
@minValue(0)
@maxValue(125)
param capacity int = 2

@description('Application Gateway capacity (autoscaling max instances)')
@minValue(2)
@maxValue(125)
param capacityMax int = 10

@description('HTTPS listeners configuration (placeholder for future listeners)')
param httpsListeners array = []

@description('Backend pools configuration (placeholder for future backend pools)')
param backendPools array = []

// =============================================================================
// Public IP Address using AVM
// =============================================================================

var effectivePublicIpName = !empty(publicIpName) ? publicIpName : 'pip-${applicationGatewayName}'

module publicIP 'br/public:avm/res/network/public-ip-address:0.3.1' = {
  name: 'pip-${uniqueString(resourceGroup().id)}'
  params: {
    name: effectivePublicIpName
    location: location
    tags: union(tags, {
      purpose: 'application-gateway'
      environment: environment
    })
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    skuName: 'Standard'
    skuTier: 'Regional'
  }
}

// =============================================================================
// WAF Policy using AVM (if not provided)
// =============================================================================

var createWafPolicy = empty(wafPolicyResourceId)
var effectiveWafPolicyName = 'wafp-${applicationGatewayName}'

module wafPolicy 'br/public:avm/res/network/application-gateway-web-application-firewall-policy:0.2.1' = if (createWafPolicy) {
  name: 'wafp-${uniqueString(resourceGroup().id)}'
  params: {
    name: effectiveWafPolicyName
    location: location
    tags: union(tags, {
      purpose: 'waf-policy'
      environment: environment
    })
    policySettings: {
      state: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: []
        }
      ]
    }
  }
}

var effectiveWafPolicyId = !empty(wafPolicyResourceId) ? wafPolicyResourceId : (createWafPolicy ? wafPolicy.outputs.resourceId : '')

// =============================================================================
// Application Gateway using AVM
// =============================================================================

module applicationGateway 'br/public:avm/res/network/application-gateway:0.7.2' = {
  name: 'agw-${uniqueString(resourceGroup().id)}'
  params: {
    name: applicationGatewayName
    location: location
    tags: union(tags, {
      purpose: 'application-gateway'
      environment: environment
    })
    sku: skuName
    autoscaleMinCapacity: capacity
    autoscaleMaxCapacity: capacityMax
    listeners: [] // Placeholder - configure HTTPS listeners here
    routingRules: [] // Placeholder - configure routing rules here
    firewallPolicyResourceId: effectiveWafPolicyId
    diagnosticSettings: !empty(logAnalyticsWorkspaceResourceId) ? [
      {
        name: 'appgw-diagnostics'
        workspaceResourceId: logAnalyticsWorkspaceResourceId
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
    // Note: Frontend IP, ports, backend pools configured via listeners/routingRules
    // Additional configuration via managedIdentities, privateEndpoints, etc.
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Application Gateway resource ID')
output applicationGatewayResourceId string = applicationGateway.outputs.resourceId

@description('Application Gateway name')
output applicationGatewayName string = applicationGateway.outputs.name

@description('Public IP address resource ID')
output publicIpResourceId string = publicIP.outputs.resourceId

@description('Public IP address')
output publicIpAddress string = publicIP.outputs.ipAddress

@description('WAF Policy resource ID')
output wafPolicyResourceId string = effectiveWafPolicyId
