# Phases 6 & 7 — Ingress Architecture & Non-HTTP Ingress: Implementation Summary

## Overview

Phases 6 and 7 implement secure web application ingress using Application Gateway WAF and support for non-HTTP ingress services via Azure Firewall DNAT.

## Phase 6 — Ingress Architecture (WAF, not Firewall)

### Phase 6.1 — Ingress Spoke + App Gateway WAF ✅

**Files Created**:
1. `platform/connectivity/bicep/ingress-spoke.bicep`
   - ✅ Creates VNet using `spoke.ingress.appgw` subnet profile
   - ✅ Connects to vHub
   - ✅ Associates forced-egress route table
   - ✅ Outputs subnet resource IDs (App Gateway, workload, private endpoints)

2. `platform/connectivity/bicep/app-gateway-waf.bicep`
   - ✅ Creates Public IP (Standard, Static)
   - ✅ Creates WAF Policy (OWASP 3.2, Bot Manager 1.0)
   - ✅ Creates Application Gateway WAF v2
   - ✅ HTTPS listener placeholders (ready for configuration)
   - ✅ Backend pool placeholders (ready for configuration)
   - ✅ Diagnostic settings to central LAW
   - ✅ Uses AVM modules: `avm/res/network/public-ip:0.3.1`, `avm/res/network/application-gateway-web-application-firewall-policy:0.2.1`, `avm/res/network/application-gateway:0.7.2`

3. `platform/connectivity/scripts/deploy-connectivity.ps1` (Updated)
   - ✅ Added `ingress` role support
   - ✅ Deploys ingress spoke VNet
   - ✅ Deploys Application Gateway with WAF
   - ✅ Retrieves route table from hub for forced egress
   - ✅ Links to central Log Analytics workspace

**Deployment Flow**:
```powershell
# Deploy ingress infrastructure
./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01" -Role ingress
```

**What happens**:
1. Allocates CIDR via IPAM for ingress VNet
2. Generates subnets from `spoke.ingress.appgw` profile
3. Deploys ingress spoke VNet with hub connection
4. Associates forced-egress route table
5. Deploys Application Gateway with WAF v2
6. Creates Public IP for App Gateway

---

### Phase 6.2 — Firewall Policy Baseline ✅

**File**: `platform/connectivity/bicep/firewall-policy.bicep` (Updated)

**Rule Collection Groups Structure**:
1. **PlatformEssential** (Priority 100)
   - Allow DNS (168.63.129.16, 169.254.169.254:53)
   - Allow Azure Metadata Service (169.254.169.254:80)
   - TODO: Add NTP and other platform essential services

2. **IngressNonHttp** (Priority 200)
   - DNAT Rule Collection (for non-HTTP ingress)
   - Allow Rule Collection (matching DNAT rules)
   - Rules populated from `inboundServicesConfig` (Phase 7.1)
   - **Note**: HTTP/HTTPS ingress goes through App Gateway WAF, NOT firewall

3. **WorkloadEgress** (Priority 300)
   - Allow Azure Cloud services
   - TODO: Add application-specific egress rules
   - TODO: Add FQDN rules for external services

**Key Design Decisions**:
- ✅ **HTTP ingress NOT forced through firewall** - App Gateway WAF handles HTTP/HTTPS
- ✅ DNAT only for non-HTTP services (SFTP, TCP, etc.)
- ✅ Minimal deployable rules with TODO comments for expansion
- ✅ Threat Intelligence mode enabled (configurable)

---

## Phase 7 — Non-HTTP Ingress (Intentional Hairpin)

### Phase 7.1 — Data-Driven DNAT Model ✅

**Files Created**:
1. `platform/connectivity/config/inbound-services.prod.json`
   - ✅ Configuration schema for inbound services
   - ✅ Each service defines:
     - `name` - Service identifier
     - `protocol` - TCP/UDP
     - `publicPort` - Port exposed on firewall
     - `privateIp` - Internal IP address
     - `privatePort` - Internal port
     - `allowedSourceIps` - Source IP ranges allowed

2. `platform/connectivity/bicep/firewall-policy.bicep` (Updated)
   - ✅ Accepts `inboundServicesConfig` parameter
   - ✅ Creates DNAT rules from config
   - ✅ Creates matching network allow rules
   - ✅ Threat Intelligence mode configurable (default: Alert)

**Example Configuration**:
```json
{
  "inboundServices": [
    {
      "name": "sftp-server-01",
      "protocol": "TCP",
      "publicPort": 22,
      "privateIp": "10.1.100.10",
      "privatePort": 22,
      "allowedSourceIps": ["0.0.0.0/0"]
    },
    {
      "name": "rdp-jumpbox",
      "protocol": "TCP",
      "publicPort": 3389,
      "privateIp": "10.1.100.20",
      "privatePort": 3389,
      "allowedSourceIps": ["203.0.113.0/24"]
    }
  ]
}
```

**Generated Rules**:
- DNAT rule: `Internet:22` → `10.1.100.10:22` (SFTP)
- Allow rule: `allowedSourceIps → 10.1.100.10:22`
- Matching DNAT + Allow rules created for each service

---

## Architecture

```
Internet
├── HTTP/HTTPS → Application Gateway WAF (Phase 6.1)
│   └── Ingress Spoke VNet
│       └── Backend Pools → Workload VNets
│
└── Non-HTTP (SFTP, TCP) → Azure Firewall DNAT (Phase 7.1)
    ├── DNAT Rules (data-driven from inbound-services.prod.json)
    └── Allow Rules (matching DNAT)
        └── Private IPs in workload VNets

All Egress → Azure Firewall (forced via route table)
```

---

## Files Created

1. `platform/connectivity/bicep/ingress-spoke.bicep`
2. `platform/connectivity/bicep/app-gateway-waf.bicep`
3. `platform/connectivity/config/inbound-services.prod.json`
4. `platform/connectivity/docs/PHASE6-7-IMPLEMENTATION.md`

---

## Files Modified

1. `platform/connectivity/bicep/firewall-policy.bicep` - Added rule collection groups and DNAT support
2. `platform/connectivity/scripts/deploy-connectivity.ps1` - Added ingress role deployment

---

## Key Features

1. **Separate Ingress Path**: HTTP via App Gateway WAF, non-HTTP via Firewall DNAT
2. **Data-Driven DNAT**: Inbound services configured via JSON, rules auto-generated
3. **Forced Egress**: Ingress spoke still routes egress through firewall
4. **WAF Baseline**: OWASP 3.2 + Bot Manager 1.0, prevention mode
5. **AVM Integration**: All modules use AVM where available

---

## Usage Examples

### Deploy Ingress Infrastructure

```powershell
./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01" -Role ingress
```

### Configure Inbound Services

1. Edit `platform/connectivity/config/inbound-services.prod.json`
2. Add service definitions
3. Update firewall policy deployment to include `inboundServicesConfig` parameter

### Deploy Firewall Policy with DNAT

```powershell
# Load inbound services config
$inboundServices = Get-Content "../config/inbound-services.prod.json" | ConvertFrom-Json

# Deploy firewall policy with DNAT rules
az deployment group create \
  --template-file firewall-policy.bicep \
  --parameters \
    firewallPolicyName="fwpolicy-prod-aue-01" \
    inboundServicesConfig="$($inboundServices.inboundServices | ConvertTo-Json -Compress)"
```

---

## Next Steps

1. **Configure App Gateway**:
   - Add HTTPS listeners with SSL certificates
   - Configure backend pools for workloads
   - Set up request routing rules

2. **Expand Firewall Rules**:
   - Add application-specific egress rules
   - Configure FQDN rules for external services
   - Add platform essential services (NTP, etc.)

3. **Monitor & Tune**:
   - Review WAF logs for false positives
   - Adjust firewall rules based on traffic patterns
   - Update threat intelligence mode as needed

---

## Validation

- ✅ All Bicep files compile successfully
- ✅ AVM modules used where available
- ✅ HTTP ingress NOT forced through firewall (correct design)
- ✅ DNAT rules generated from configuration
- ✅ Matching allow rules created for DNAT services
