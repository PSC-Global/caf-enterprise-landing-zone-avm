// =============================================================================
// Platform Naming Conventions
// =============================================================================
// Purpose: Helper functions and variables for consistent resource naming
//          across all platform modules
// Usage:   Import into modules to ensure naming consistency
// =============================================================================

// =============================================================================
// Naming Pattern
// =============================================================================
// Pattern: <org>-<env>-<region>-<domain>-<resource>-<purpose>-<nn>
//
// Components:
// - org: Organization prefix (e.g., 'rai')
// - env: Environment (e.g., 'prod', 'nonprod')
// - region: Region short code (e.g., 'aue' for Australia East, 'ause' for Australia Southeast)
// - domain: Domain/workload type (e.g., 'corp', 'online', 'platform', 'ingress', 'shared')
// - resource: Resource type abbreviation (e.g., 'vnet', 'kv', 'agw')
// - purpose: Purpose or application (e.g., 'lending', 'identity', 'connectivity')
// - nn: Sequential number (e.g., '01', '02')

// =============================================================================
// Organization Prefix
// =============================================================================
var orgPrefix = 'rai'

// =============================================================================
// Region Short Codes
// =============================================================================
// Standard region abbreviations for naming consistency
// australiaeast -> aue
// australiasoutheast -> ause

// Helper function to convert full region name to short code
@description('Converts Azure region name to short code for naming')
func getRegionShortCode(region string) string => {
  regionCode: region == 'australiaeast' ? 'aue'
    : region == 'australiasoutheast' ? 'ause'
    : region == 'australiacentral' ? 'auc'
    : region == 'australiacentral2' ? 'auc2'
    : replace(replace(replace(toLower(region), ' ', ''), '-', ''), 'australia', 'au')
}

// =============================================================================
// Resource Type Abbreviations
// =============================================================================
// Standard abbreviations for resource types in naming
var resourceTypes = {
  virtualNetwork: 'vnet'
  subnet: 'snet'
  networkSecurityGroup: 'nsg'
  routeTable: 'rt'
  privateDnsZone: 'pdns'
  keyVault: 'kv'
  applicationGateway: 'agw'
  publicIP: 'pip'
  wafPolicy: 'wafp'
  logAnalyticsWorkspace: 'law'
  virtualWan: 'vwan'
  virtualHub: 'vhub'
  azureFirewall: 'fw'
}

// =============================================================================
// Naming Functions
// =============================================================================

// Full resource name following standard pattern
@description('Generates a resource name following the standard naming pattern')
func buildResourceName(
  org string
  env string
  regionCode string
  domain string
  resourceType string
  purpose string
  instanceNumber string
) string => '${org}-${env}-${regionCode}-${domain}-${resourceType}-${purpose}-${instanceNumber}'

// Simplified resource name (without domain, for context-specific resources)
@description('Generates a simplified resource name without domain component')
func buildSimpleResourceName(
  org string
  env string
  regionCode string
  resourceType string
  purpose string
  instanceNumber string
) string => '${org}-${env}-${regionCode}-${resourceType}-${purpose}-${instanceNumber}'

// Subnet name (contextual, within VNet)
@description('Generates a subnet name (contextual, within VNet scope)')
func buildSubnetName(purpose string) string => 'snet-${purpose}'

// NSG/Route Table name (contextual)
@description('Generates NSG or route table name (contextual)')
func buildNetworkPolicyName(resourceType string, purpose string) string => '${resourceType}-${purpose}'

// =============================================================================
// Common Domain Values
// =============================================================================
var domains = {
  platform: 'platform'
  identity: 'identity'
  connectivity: 'connectivity'
  management: 'management'
  corp: 'corp'
  online: 'online'
  ingress: 'ingress'
  shared: 'shared'
}

// =============================================================================
// Common Purpose Values
// =============================================================================
var purposes = {
  workload: 'workload'
  privateEndpoints: 'private-endpoints'
  appGateway: 'appgw'
  integration: 'integration'
  management: 'mgmt'
  egress: 'egress'
  ingress: 'ingress'
}

// =============================================================================
// Subnet Purpose Names
// =============================================================================
var subnetPurposes = {
  workload: 'workload'
  privateEndpoints: 'private-endpoints'
  appGateway: 'appgw'
  integration: 'integration'
  management: 'mgmt'
}

// Note: This file provides naming conventions and helper functions.
//       Individual modules should use these patterns to ensure consistency
//       across the platform.
