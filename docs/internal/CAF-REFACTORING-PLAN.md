# CAF-Aligned Refactoring Plan
## Split Hub Deployment into Modular Stages

## Overview

Refactor the connectivity deployment to align with CAF best practices while maintaining backward compatibility. Split the monolithic `vwan-hub.bicep` into separate modules for independent lifecycle management.

---

## Current State Analysis

### Current Structure
- **`vwan-hub.bicep`**: Deploys vWAN, vHub, Azure Firewall, Routing Intent, VPN Gateway (all together)
- **`firewall-policy.bicep`**: Already separate ✅
- **`route-intent.bicep`**: Already separate ✅
- **`private-dns-zones.bicep`**: Already separate ✅
- **Script**: `deploy-connectivity.ps1` orchestrates all phases

### Issues
- Firewall changes require full hub redeployment
- No granular control over deployment stages
- Tight coupling between hub core and security services
- Cannot deploy firewall independently

---

## Target State (CAF-Aligned)

### Module Structure (Phase-Based)

#### Phase A: Hub Core (`hub-core.bicep`) - Rare Changes
- Virtual WAN
- Virtual Hub
- Hub address space
- Tags
- **Outputs**: vWAN ID, vHub ID, vHub name

#### Phase B: Security Edge (`firewall.bicep`) - More Frequent Changes
- Azure Firewall resource
- **Dependencies**: vHub ID (from Phase A), Firewall Policy ID (from Phase B.1)
- **Outputs**: Azure Firewall ID

#### Phase B.1: Firewall Policy (`firewall-policy.bicep`) - Most Frequent Changes
- Firewall Policy (already separate ✅)
- Rule Collections
- **Outputs**: Firewall Policy ID

#### Phase C: Routing (`routing-intent.bicep`) - Carefully Controlled
- Routing Intent (already separate ✅)
- **Dependencies**: vHub ID, Azure Firewall ID
- **Outputs**: Routing Intent ID
- **Note**: Mutually exclusive with custom route tables (already enforced ✅)

#### Phase D: DNS & Private Endpoints (`private-dns-zones.bicep`) - Broad Blast Radius
- Private DNS zones (already separate ✅)
- VNet links (`private-dns-links.bicep`)
- **Outputs**: DNS Zone IDs

#### Optional: VPN Gateway
- VPN Gateway (can be added to `hub-core.bicep` or separate module)
- **Currently**: Part of `vwan-hub.bicep`

---

## Implementation Plan

### Step 1: Create New Modular Bicep Files

#### 1.1 Create `hub-core.bicep`
- Extract vWAN + vHub from `vwan-hub.bicep`
- Remove Azure Firewall, Routing Intent, VPN Gateway
- Keep standard parameters (environment, location, tags)
- Outputs: vWAN ID, vHub ID, vHub name, vHub address prefix

#### 1.2 Create `firewall.bicep`
- Extract Azure Firewall from `vwan-hub.bicep`
- Parameters: vHub ID, Firewall Policy ID, SKU, location, tags
- Outputs: Azure Firewall ID

#### 1.3 Keep Existing Modules (No Changes)
- `firewall-policy.bicep` ✅
- `route-intent.bicep` ✅
- `private-dns-zones.bicep` ✅

### Step 2: Update Script with Stage Parameters

#### 2.1 Add Stage Control Parameters
```powershell
param(
    [string]$SubscriptionId,
    [switch]$DeployHubCore,
    [switch]$DeployFirewall,
    [switch]$DeployFirewallPolicy,
    [switch]$DeployRouting,
    [switch]$DeployPrivateDns,
    [switch]$DeployAll  # Default: true for backward compatibility
)
```

#### 2.2 Implement Stage-Based Logic
- If `-DeployAll` (default): Deploy all stages (backward compatible)
- If specific stage flags: Deploy only those stages
- Maintain dependency ordering:
  1. Hub Core (always first if needed)
  2. Firewall Policy (before Firewall)
  3. Firewall (after Hub Core + Firewall Policy)
  4. Routing (after Firewall)
  5. Private DNS (independent)

#### 2.3 Update Deployment Flow
```powershell
# Phase A: Hub Core
if ($DeployAll -or $DeployHubCore) {
    Deploy-HubCore
}

# Phase B.1: Firewall Policy
if ($DeployAll -or $DeployFirewallPolicy) {
    Deploy-FirewallPolicy
}

# Phase B: Firewall
if ($DeployAll -or $DeployFirewall) {
    Deploy-Firewall  # Requires Hub Core + Firewall Policy
}

# Phase C: Routing
if ($DeployAll -or $DeployRouting) {
    Deploy-Routing  # Requires Hub Core + Firewall
}

# Phase D: Private DNS
if ($DeployAll -or $DeployPrivateDns) {
    Deploy-PrivateDns  # Independent
}
```

### Step 3: Maintain Backward Compatibility

#### 3.1 Keep `vwan-hub.bicep` as Orchestrator (Option A - Recommended)
- Keep `vwan-hub.bicep` but refactor it to call new modules
- This preserves existing script calls
- Internal refactoring only

#### 3.2 OR Deprecate `vwan-hub.bicep` (Option B - Cleaner but breaking)
- Remove `vwan-hub.bicep`
- Update script to call modules directly
- Update all references

**Decision**: Use **Option A** for backward compatibility.

### Step 4: Update Outputs and Dependencies

#### 4.1 Stable Output Contracts
- Each module outputs resource IDs
- Script captures and stores outputs for next stage
- Output format consistent across modules

#### 4.2 Dependency Resolution
- Script reads outputs from previous stage deployments
- Uses Azure deployment queries if outputs not available
- Handles partial deployments gracefully

### Step 5: Routing Exclusivity (Already Done ✅)
- Routing Intent and custom route tables are mutually exclusive
- Current implementation only uses Routing Intent
- No changes needed

---

## File Changes Summary

### New Files
1. `platform/connectivity/bicep/hub-core.bicep` - NEW
2. `platform/connectivity/bicep/firewall.bicep` - NEW

### Modified Files
1. `platform/connectivity/bicep/vwan-hub.bicep` - Refactor to use new modules (or keep as orchestrator)
2. `platform/connectivity/scripts/deploy-connectivity.ps1` - Add stage parameters and logic

### Unchanged Files (No Changes)
1. `platform/connectivity/bicep/firewall-policy.bicep` - ✅
2. `platform/connectivity/bicep/route-intent.bicep` - ✅
3. `platform/connectivity/bicep/private-dns-zones.bicep` - ✅
4. `platform/connectivity/bicep/private-dns-links.bicep` - ✅

---

## Testing Strategy

### Backward Compatibility Tests
1. Run existing script without new parameters → Should work as before
2. Verify all resources deploy correctly
3. Verify outputs match previous format

### Stage-Based Deployment Tests
1. Deploy Hub Core only → Verify vWAN + vHub created
2. Deploy Firewall Policy only → Verify policy created
3. Deploy Firewall only → Verify firewall created (requires Hub Core + Policy)
4. Deploy Routing only → Verify routing intent created (requires Hub Core + Firewall)
5. Deploy all stages sequentially → Verify end-to-end deployment

### Integration Tests
1. Deploy Hub Core → Deploy Firewall → Verify firewall attached to hub
2. Deploy Firewall Policy separately → Update rules → Redeploy firewall → Verify new rules applied
3. Partial deployments → Verify script handles missing dependencies gracefully

---

## Migration Path

### Phase 1: Create New Modules (Non-Breaking)
- Create `hub-core.bicep` and `firewall.bicep`
- Keep `vwan-hub.bicep` unchanged
- Test new modules independently

### Phase 2: Update Script (Backward Compatible)
- Add stage parameters (default to `-DeployAll`)
- Implement stage-based logic
- Keep existing flow as default
- Test backward compatibility

### Phase 3: Refactor vwan-hub.bicep (Optional)
- Option A: Keep as orchestrator calling new modules
- Option B: Deprecate and update script to call modules directly
- **Recommendation**: Option A for zero breaking changes

### Phase 4: Documentation & Adoption
- Update runbook with new stage-based deployment options
- Document when to use staged vs. full deployment
- Train team on new capabilities

---

## Success Criteria

✅ **Backward Compatibility**
- Existing scripts work without changes
- All outputs remain stable
- No breaking changes to API contracts

✅ **CAF Alignment**
- Clear separation of concerns
- Independent lifecycle management
- Granular deployment control
- Proper dependency ordering

✅ **Operational Benefits**
- Deploy firewall policy changes without hub redeployment
- Deploy firewall independently
- Deploy routing independently
- Reduced blast radius for changes

✅ **Code Quality**
- Modular, reusable Bicep files
- Clear dependencies
- Stable output contracts
- Well-documented stages

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing deployments | High | Use Option A (keep vwan-hub as orchestrator) |
| Output format changes | Medium | Maintain stable output contracts, test thoroughly |
| Dependency ordering issues | Medium | Implement dependency validation in script |
| Increased complexity | Low | Clear documentation, stage-based approach is intuitive |

---

## Timeline Estimate

- **Step 1** (Create modules): 2-3 hours
- **Step 2** (Update script): 2-3 hours
- **Step 3** (Backward compatibility): 1-2 hours
- **Step 4** (Testing): 2-3 hours
- **Step 5** (Documentation): 1 hour

**Total**: ~8-12 hours of focused work

---

## Next Steps

1. Review and approve this plan
2. Create `hub-core.bicep` (extract from `vwan-hub.bicep`)
3. Create `firewall.bicep` (extract from `vwan-hub.bicep`)
4. Update `deploy-connectivity.ps1` with stage parameters
5. Test backward compatibility
6. Test stage-based deployments
7. Update documentation

---

**Plan Version**: 1.0  
**Created**: 2026-01-11  
**Status**: Ready for Implementation
