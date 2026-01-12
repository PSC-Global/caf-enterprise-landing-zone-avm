// =============================================================================
// Platform Shared Contract
// =============================================================================
// Purpose: Defines standard parameters used across all platform modules
//          to ensure consistency and prevent divergence
// Usage:   Import this file using: param contract = loadTextContent('../shared/contract.bicep')
//          Then reference: contract.environment, contract.location, etc.
//
// Note: This is a Bicep parameter file pattern - parameters are defined
//       in consuming modules by importing standard definitions below.
// =============================================================================

// =============================================================================
// Standard Parameter Definitions
// =============================================================================
// All platform modules should include these standard parameters with
// consistent naming, types, and defaults.

// -----------------------------------------------------------------------------
// Environment
// -----------------------------------------------------------------------------
// @description('Deployment environment')
// param environment string = 'prod'

// -----------------------------------------------------------------------------
// Location
// -----------------------------------------------------------------------------
// @description('Azure region for resource deployment')
// param location string

// -----------------------------------------------------------------------------
// Tags
// -----------------------------------------------------------------------------
// @description('Tags to apply to all resources')
// param tags object

// -----------------------------------------------------------------------------
// Log Analytics Workspace Resource ID
// -----------------------------------------------------------------------------
// @description('Log Analytics Workspace resource ID for diagnostics')
// param logAnalyticsWorkspaceResourceId string = ''

// =============================================================================
// Standard Output Definitions
// =============================================================================
// Modules that create shared platform resources should output these
// standardized output names for downstream consumption.

// Standard output names:
// - logAnalyticsWorkspaceResourceId: Log Analytics Workspace resource ID
// - virtualHubResourceId: Virtual Hub resource ID  
// - azureFirewallResourceId: Azure Firewall resource ID
// - virtualWanResourceId: Virtual WAN resource ID

// Note: This file serves as documentation and reference.
//       Individual modules define their own parameters but should follow
//       these naming conventions.
