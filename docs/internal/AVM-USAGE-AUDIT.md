# AVM Usage Audit Report

## Summary

This document audits whether Azure Verified Modules (AVM) are used wherever feasible across all Bicep modules.

## AVM Modules Used ✅

### Network Resources
- ✅ **Virtual WAN**: `br/public:avm/res/network/virtual-wan:0.4.3`
- ✅ **Virtual Hub**: `br/public:avm/res/network/virtual-hub:0.4.3`
- ✅ **Azure Firewall**: `br/public:avm/res/network/azure-firewall:0.9.2`
- ✅ **VPN Gateway**: `br/public:avm/res/network/vpn-gateway:0.2.2`
- ✅ **Virtual Network**: `br/public:avm/res/network/virtual-network:0.5.1`
- ✅ **Application Gateway**: `br/public:avm/res/network/application-gateway:0.7.2`
- ✅ **Application Gateway WAF Policy**: `br/public:avm/res/network/application-gateway-web-application-firewall-policy:0.2.1`
- ✅ **Public IP Address**: `br/public:avm/res/network/public-ip-address:0.3.1`
- ✅ **Private DNS Zone**: `br/public:avm/res/network/private-dns-zone:0.7.1`
- ✅ **Private Endpoint**: `br/public:avm/res/network/private-endpoint:0.9.0`

### Resource Management
- ✅ **Resource Group**: `br/public:avm/res/resources/resource-group:0.4.0`

## Native Bicep (Justified Reasons) ⚠️

### 1. Firewall Policy (`firewall-policy.bicep`)
**AVM Available**: `br/public:avm/res/network/firewall-policy:0.1.1`

**Reason for Native Bicep**:
- ✅ **Justified**: Child resources (rule collection groups) require direct resource references
- ✅ AVM module outputs cannot be used as `parent` for child resources in Bicep
- ✅ Complex rule collection groups with data-driven DNAT rules (Phase 6.2, 7.1) need native Bicep
- ✅ Rule collection groups are added as child resources with dynamic content (for loops)

**Alternative Considered**: 
- AVM module exists but doesn't support our use case of adding child resources after creation
- Could use AVM if rule collection groups were managed separately, but that defeats the purpose of a cohesive module

### 2. Private DNS Zone Virtual Network Links (`private-dns-links.bicep`)
**AVM Available**: ❌ **Not available**

**Reason for Native Bicep**:
- ✅ **Justified**: No AVM module exists for DNS zone VNet links (confirmed via web search)
- Native Bicep is the only option

### 3. Route Intent (`route-intent.bicep`)
**AVM Available**: ❌ **Not available**

**Reason for Native Bicep**:
- ✅ **Justified**: Route Intent is a vWAN-specific feature with no AVM module
- Native Bicep is the only option

### 4. Virtual Hub Connections (in `spoke-vnet.bicep`, `vnet-connection.bicep`)
**AVM Available**: ⚠️ **Limited support**

**Reason for Native Bicep**:
- ✅ **Justified**: AVM virtual-hub module doesn't fully support connections
- Connection resources need route table associations (Phase 4.2)
- Child resource pattern requires native Bicep

### 5. Diagnostic Settings
**AVM Available**: ❌ **N/A**

**Reason for Native Bicep**:
- ✅ **Justified**: Diagnostic settings are child resources, typically added inline
- Standard practice to use native Bicep for diagnostic settings

### 6. Action Groups (`platform/logging/bicep/action-groups.bicep`)
**AVM Available**: ❌ **Not available**

**Reason for Native Bicep**:
- ✅ **Justified**: No AVM module exists for action groups (confirmed in Phase 1)
- Native Bicep is the only option

## Findings

### ✅ Correct AVM Usage
- **11 modules** correctly use AVM where available
- All major networking resources use AVM
- Proper version pinning applied

### ⚠️ Native Bicep Cases
- **1 case** where AVM exists but can't be used due to child resource limitations (Firewall Policy)
- **4 cases** where AVM doesn't exist (DNS links, Route Intent, Action Groups, Diagnostic Settings)
- **1 case** where AVM has limited support (Hub connections)

## Recommendation

### Firewall Policy Module
**Current Status**: Using native Bicep

**Recommendation**: **Keep native Bicep** (justified)
- Child resource requirement makes AVM impractical
- Complex rule collection groups with dynamic content need native Bicep
- Documented with clear comments explaining the limitation

### Future Considerations
1. Monitor AVM module updates for:
   - Firewall Policy with better child resource support
   - Private DNS Zone VNet Links module
   - Route Intent module
2. If AVM modules add support, migrate accordingly
3. Current implementation follows best practices given constraints

## Conclusion

✅ **AVM is used wherever feasible and practical**

All AVM modules are used except:
- Cases where AVM doesn't exist (4 modules)
- 1 case where technical limitations prevent AVM usage (Firewall Policy with child resources)

The single case of native Bicep where AVM exists (Firewall Policy) is **justified** due to child resource limitations that prevent using the AVM module effectively with our requirements.
