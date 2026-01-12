# Phase 2 — IP Governance & Subnet Standards: Implementation Summary

## Overview

Phase 2 implements data-driven networking with deterministic IP allocation and subnet profile standards.

## What Was Implemented

### Phase 2.1 — Subnet Profiles (Subsets)

**File**: `platform/connectivity/config/subnet-blueprints.json`

- ✅ Extended with `profiles` structure (backward compatible with existing `blueprints`)
- ✅ Added 4 required profiles:
  - `spoke.workload.standard` - Standard workload spoke with mandatory `snet-private-endpoints`
  - `spoke.workload.private-endpoints` - Workload focused on private endpoints
  - `spoke.ingress.appgw` - Ingress spoke with mandatory `snet-appgw`
  - `spoke.shared-services` - Shared services spoke
- ✅ Each subnet includes:
  - `name` - Subnet name (with `snet-` prefix)
  - `cidrSize` - CIDR size (e.g., 26 for /26)
  - `purpose` - Subnet purpose (workload, private-endpoints, appgw, etc.)
  - `associateNsg` - Boolean flag for NSG association
  - `associateRouteTable` - Boolean flag for route table association
- ✅ Backward compatibility maintained - existing blueprints still work

### Phase 2.2 — IPAM Allocation Automation

**File**: `platform/connectivity/scripts/ipam-allocate.ps1`

- ✅ Local IPAM allocation script (no external dependencies)
- ✅ Reads `ipam.json` as source pools
- ✅ Allocates CIDRs per allocation key (e.g., `rai-lending-core-prod-01-workload`)
- ✅ Persists state in `platform/connectivity/generated/ipam-state.json`
- ✅ Prevents conflicts by tracking all allocations
- ✅ Supports release operations
- ✅ Designed with hooks for future Azure IPAM API integration

**State File Format**: `platform/connectivity/generated/ipam-state.json`
- Tracks all allocations with metadata
- JSON format for easy parsing
- Includes timestamps and status

### Integration Updates

**File**: `platform/connectivity/scripts/deploy-connectivity.ps1`

- ✅ Added `Get-SubnetBlueprint()` - Loads subnet profiles/blueprints
- ✅ Added `Generate-Subnets()` - Generates subnet configurations from VNet CIDR
- ✅ Added `Invoke-IpamAllocation()` - Calls IPAM allocation script
- ✅ Updated spoke deployment to:
  1. Allocate CIDR via IPAM (Phase 2.2)
  2. Load subnet blueprint profile
  3. Generate subnets with calculated CIDRs
  4. Pass subnets to `spoke-vnet.bicep`

### Configuration Updates

**File**: `platform/connectivity/config/ipam.json`

- ✅ Added `rai-lending-core-prod-01` entry:
  - Space: `rai`
  - Block: `rai-spokes-aue-prod`
  - VNet CIDR size: `/24`
  - Subnet blueprint: `spoke.workload.standard`

## Usage Example

### Deploy Spoke VNet for Lending Core

```powershell
cd platform/connectivity/scripts
./deploy-connectivity.ps1 -SubscriptionId "rai-lending-core-prod-01"
```

**What happens:**
1. Script loads IPAM config for `rai-lending-core-prod-01`
2. Calls `ipam-allocate.ps1` to allocate `/24` CIDR from `rai-spokes-aue-prod` space
3. Loads `spoke.workload.standard` profile from subnet-blueprints.json
4. Generates 4 subnets:
   - `snet-workload` (/26)
   - `snet-private-endpoints` (/27) - mandatory
   - `snet-integration` (/27)
   - `snet-mgmt` (/27)
5. Deploys VNet with allocated CIDR and generated subnets

### Manual IPAM Allocation

```powershell
# Allocate CIDR
./ipam-allocate.ps1 -AllocationKey "rai-lending-core-prod-01-workload" -CidrSize 24 -SubscriptionAlias "rai-lending-core-prod-01"

# Release allocation
./ipam-allocate.ps1 -AllocationKey "rai-lending-core-prod-01-workload" -Release
```

## State Management

### IPAM State File

Location: `platform/connectivity/generated/ipam-state.json`

The state file tracks all CIDR allocations to prevent conflicts. It's automatically managed by `ipam-allocate.ps1`.

**Important**: 
- State file should be committed to version control (or excluded if sensitive)
- Regular backups recommended before major network changes
- State file format compatible with future Azure IPAM API integration

## Future Enhancements

### Azure IPAM Integration

The implementation includes hooks for future Azure IPAM API integration:

1. `Request-AzureIpamAllocation()` function placeholder in `ipam-allocate.ps1`
2. State file format compatible with Azure IPAM
3. Can be extended to check Azure IPAM API first, fallback to local state

### Next Steps

1. Deploy Azure IPAM application (see `IPAM-SETUP.md`)
2. Update `ipam-allocate.ps1` to call Azure IPAM API
3. Sync local state with Azure IPAM for backup/audit

## Files Created/Modified

### Created
- `platform/connectivity/scripts/ipam-allocate.ps1`
- `platform/connectivity/generated/.gitkeep`
- `platform/connectivity/generated/ipam-state.json.example`
- `platform/connectivity/generated/README.md`
- `platform/connectivity/docs/PHASE2-IMPLEMENTATION.md`

### Modified
- `platform/connectivity/config/subnet-blueprints.json` - Added profiles structure
- `platform/connectivity/config/ipam.json` - Added lending-core entry
- `platform/connectivity/scripts/deploy-connectivity.ps1` - Integrated IPAM and subnet generation

## Validation

- ✅ All files pass linting
- ✅ Backward compatibility maintained
- ✅ No breaking changes to existing consumers
- ✅ State file format documented
- ✅ Ready for `rai-lending-core-prod-01` deployment
