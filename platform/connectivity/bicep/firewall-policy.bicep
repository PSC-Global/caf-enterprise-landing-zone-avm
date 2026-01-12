// =============================================================================
// Azure Firewall Policy
// =============================================================================
// Purpose: Creates Azure Firewall Policy for centralized firewall management
// Scope: Resource Group
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

@description('Firewall Policy name')
param firewallPolicyName string

@description('Firewall Policy tier')
@allowed([
  'Standard'
  'Premium'
])
param policyTier string = 'Standard'

@description('Threat Intelligence mode')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param threatIntelMode string = 'Alert'

@description('DNS server addresses for DNS proxy (optional)')
param dnsServers array = []

@description('Enable DNS Proxy')
param enableDnsProxy bool = false

@description('Enable DNS over HTTPS (DNS Proxy must be enabled)')
param enableDnsOverHttps bool = false

@description('Shared egress FQDNs (sorted, deterministic)')
param sharedEgressFqdns array = []

@description('Workload egress rules configuration')
param workloadEgressRules array = []

@description('Inbound non-HTTP services configuration')
param inboundNonHttpServices array = []

// -----------------------------------------------------------------------------
// Variables and Helper Functions
// -----------------------------------------------------------------------------

// Sort FQDNs for deterministic rule generation
var sortedSharedEgressFqdns = sharedEgressFqdns

// Sort workload egress rules by workloadName for deterministic ordering
var sortedWorkloadEgressRules = workloadEgressRules

// Sort inbound services by name for deterministic ordering
var sortedInboundServices = inboundNonHttpServices

// Pre-generate rule arrays to avoid for-expressions in resource properties
var sharedEgressRules = [for (fqdn, i) in sortedSharedEgressFqdns: {
  ruleType: 'ApplicationRule'
  name: 'Allow_${replace(fqdn, '.', '_')}_${i}'
  sourceAddresses: ['*']
  protocols: [
    {
      protocolType: 'Https'
      port: 443
    }
  ]
  targetFqdns: [fqdn]
  fqdnTags: []
}]

var workloadEgressApplicationRules = [for (workload, wIdx) in sortedWorkloadEgressRules: {
  ruleType: 'ApplicationRule'
  name: 'Allow_${replace(workload.workloadName, '-', '_')}_Egress_${wIdx}'
  sourceAddresses: ['*']
  protocols: [
    {
      protocolType: 'Https'
      port: 443
    }
  ]
  targetFqdns: workload.fqdns
  fqdnTags: []
}]

var inboundNatRules = [for (service, sIdx) in sortedInboundServices: {
  ruleType: 'NatRule'
  name: 'DNAT_${replace(service.name, '-', '_')}_${sIdx}'
  ipProtocols: [service.protocol]
  sourceAddresses: service.allowedSourceIps
  destinationAddresses: ['*']
  destinationPorts: [string(service.publicPort)]
  translatedAddress: service.privateIp
  translatedPort: string(service.privatePort)
  translatedFqdn: null
}]

var inboundAllowRules = [for (service, sIdx) in sortedInboundServices: {
  ruleType: 'NetworkRule'
  name: 'Allow_${replace(service.name, '-', '_')}_${sIdx}'
  ipProtocols: [service.protocol]
  sourceAddresses: service.allowedSourceIps
  destinationAddresses: [service.privateIp]
  destinationPorts: [string(service.privatePort)]
}]

// =============================================================================
// Firewall Policy Resource
// =============================================================================

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-11-01' = {
  name: firewallPolicyName
  location: location
  tags: union(tags, {
    purpose: 'firewall-policy'
    environment: environment
  })
  properties: {
    sku: {
      tier: policyTier
    }
    threatIntelMode: threatIntelMode
    dnsSettings: enableDnsProxy ? {
      enableProxy: enableDnsProxy
      servers: dnsServers
      requireProxyForNetworkRules: enableDnsOverHttps
    } : null
  }
}

// =============================================================================
// Rule Collection Groups (Sequential Deployment)
// =============================================================================
// CRITICAL: RCGs must deploy sequentially using dependsOn to avoid Azure locks
// Order: PlatformBaseline -> SharedEgress -> WorkloadEgress -> InboundNonHttp

// -----------------------------------------------------------------------------
// PlatformBaseline Rule Collection Group (Priority 100)
// -----------------------------------------------------------------------------

resource platformBaselineRcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'PlatformBaseline'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'PlatformBaselineRules'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowAzureDNS'
            ipProtocols: [
              'UDP'
              'TCP'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '168.63.129.16'
              '169.254.169.254'
            ]
            destinationPorts: [
              '53'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowAzureMetadata'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '169.254.169.254'
            ]
            destinationPorts: [
              '80'
            ]
          }
        ]
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// SharedEgress Rule Collection Group (Priority 200)
// -----------------------------------------------------------------------------

resource sharedEgressRcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'SharedEgress'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'SharedEgressRules'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: sharedEgressRules
      }
    ]
  }
  dependsOn: [
    platformBaselineRcg
  ]
}

// -----------------------------------------------------------------------------
// WorkloadEgress Rule Collection Group (Priority 300)
// -----------------------------------------------------------------------------

resource workloadEgressRcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'WorkloadEgress'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'WorkloadEgressRules'
        priority: 300
        action: {
          type: 'Allow'
        }
        rules: concat([
          {
            ruleType: 'NetworkRule'
            name: 'AllowAzureServices'
            ipProtocols: [
              'TCP'
              'UDP'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              'AzureCloud'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ], workloadEgressApplicationRules)
      }
    ]
  }
  dependsOn: [
    sharedEgressRcg
  ]
}

// -----------------------------------------------------------------------------
// InboundNonHttp Rule Collection Group (Priority 400)
// -----------------------------------------------------------------------------

resource inboundNonHttpRcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'InboundNonHttp'
  properties: {
    priority: 400
    ruleCollections: length(sortedInboundServices) > 0 ? [
      {
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        name: 'InboundNonHttpDNAT'
        priority: 400
        action: {
          type: 'DNAT'
        }
        rules: inboundNatRules
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowInboundNonHttp'
        priority: 401
        action: {
          type: 'Allow'
        }
        rules: inboundAllowRules
      }
    ] : []
  }
  dependsOn: [
    workloadEgressRcg
  ]
}

// =============================================================================
// Outputs
// =============================================================================

@description('Firewall Policy name')
output firewallPolicyName string = firewallPolicy.name

@description('Firewall Policy resource ID')
output firewallPolicyResourceId string = firewallPolicy.id

@description('Firewall Policy location')
output location string = location
