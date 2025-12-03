// -----------------------------------------------------------------------------
// Azure Verified Modules (AVM) - CAF Management Group Hierarchy
// Author: Varun Rai
// Purpose: Create RAI → Platform → Landing Zones → Sandbox hierarchy
// Important: Management groups are deployed asynchronously by ARM.
//            Parent MGs MUST finish before child MG creation.
// -----------------------------------------------------------------------------

targetScope = 'managementGroup'

// Short org ID for MG hierarchy
param orgId string = 'rai'
param orgDisplayName string = 'RAI'

// Tenant Root Group ID (GUID)
var rootMgId = tenant().tenantId



// ============================================================================
// ROOT MANAGEMENT GROUP: /rai
// ============================================================================
// No dependsOn needed because this is the first MG and uses tenant root as parent.
module mg_rai 'br/public:avm/res/management/management-group:0.1.2' = {
  name: 'mg-rai'
  scope: managementGroup(rootMgId)
  params: {
    name: orgId                // 'rai'
    displayName: orgDisplayName
    parentId: rootMgId         // Tenant Root Group
  }
}



// ============================================================================
// PLATFORM MG (PARENT: RAI)
// ============================================================================
// IMPORTANT: Must depend on mg_rai
// Reason:
//   ARM deploys modules IN PARALLEL unless explicitly ordered.
//   Without dependsOn, ARM may try to create 'platform' BEFORE 'rai' exists,
//   causing "Parent management group 'rai' not found" errors.
// ============================================================================
module mg_platform 'br/public:avm/res/management/management-group:0.1.2' = {
  name: 'mg-platform'
  scope: managementGroup(rootMgId)
  dependsOn: [
    mg_rai
  ]
  params: {
    name: 'platform'
    displayName: 'Platform'
    parentId: orgId             // Parent is 'rai'
  }
}



// ============================================================================
// LANDING ZONES MG (PARENT: RAI)
// ============================================================================
module mg_lz 'br/public:avm/res/management/management-group:0.1.2' = {
  name: 'mg-lz'
  scope: managementGroup(rootMgId)
  dependsOn: [
    mg_rai                      // Ensure 'rai' is created first
  ]
  params: {
    name: 'landing-zones'
    displayName: 'Landing Zones'
    parentId: orgId
  }
}



// ============================================================================
// SANDBOX MG (PARENT: RAI)
// ============================================================================
module mg_sandbox 'br/public:avm/res/management/management-group:0.1.2' = {
  name: 'mg-sandbox'
  scope: managementGroup(rootMgId)
  dependsOn: [
    mg_rai                      // Sandbox also must attach under 'rai'
  ]
  params: {
    name: 'sandbox'
    displayName: 'Sandbox'
    parentId: orgId
  }
}



// ============================================================================
// PLATFORM CHILDREN (PARENT: PLATFORM)
// ============================================================================
// IMPORTANT: These must depend on mg_platform
// Reason:
//   'platform' is created asynchronously.
//   Without dependsOn, ARM may attempt to create platform-* MGs first,
//   causing: "Parent management group 'platform' not found".
module mg_platform_mgmt 'br/public:avm/res/management/management-group:0.1.2' = {
  name: 'mg-platform-mgmt'
  scope: managementGroup(rootMgId)
  dependsOn: [
    mg_platform
  ]
  params: {
    name: 'platform-management'
    displayName: 'Platform - Management'
    parentId: 'platform'
  }
}

module mg_platform_identity 'br/public:avm/res/management/management-group:0.1.2' = {
  name: 'mg-platform-identity'
  scope: managementGroup(rootMgId)
  dependsOn: [
    mg_platform
  ]
  params: {
    name: 'platform-identity'
    displayName: 'Platform - Identity'
    parentId: 'platform'
  }
}

module mg_platform_connectivity 'br/public:avm/res/management/management-group:0.1.2' = {
  name: 'mg-platform-connectivity'
  scope: managementGroup(rootMgId)
  dependsOn: [
    mg_platform
  ]
  params: {
    name: 'platform-connectivity'
    displayName: 'Platform - Connectivity'
    parentId: 'platform'
  }
}



// ============================================================================
// LANDING ZONES CHILDREN (PARENT: LANDING ZONES)
// ============================================================================
// Same logic: landing-zones must exist before its children.
module mg_lz_corp 'br/public:avm/res/management/management-group:0.1.2' = {
  name: 'mg-lz-corp'
  scope: managementGroup(rootMgId)
  dependsOn: [
    mg_lz
  ]
  params: {
    name: 'corp'
    displayName: 'Corp'
    parentId: 'landing-zones'
  }
}

module mg_lz_online 'br/public:avm/res/management/management-group:0.1.2' = {
  name: 'mg-lz-online'
  scope: managementGroup(rootMgId)
  dependsOn: [
    mg_lz
  ]
  params: {
    name: 'online'
    displayName: 'Online'
    parentId: 'landing-zones'
  }
}
