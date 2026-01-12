# Production Deployment Runbook

This runbook provides step-by-step instructions for deploying the complete CAF Enterprise Landing Zone platform to production.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Deployment Order](#deployment-order)
3. [Detailed Deployment Steps](#detailed-deployment-steps)
4. [Validation Checklist](#validation-checklist)
5. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Azure CLI & Authentication

```bash
# Install Azure CLI (if not already installed)
# macOS: brew install azure-cli
# Windows: https://aka.ms/installazurecliwindows

# Login with appropriate permissions
az login

# Verify you have Owner or equivalent permissions
az account show --output table
az account list-locations --output table
```

### Required Permissions

- **Tenant Root**: Owner or Management Group Contributor
- **Subscriptions**: Owner (for subscription creation) or Contributor (for resource deployment)
- **Azure AD**: Global Administrator or Privileged Role Administrator (for AAD group creation)

### Repository Setup

```bash
# Clone repository
git clone <repository-url>
cd caf-enterprise-landing-zone-avm

# Verify Bicep CLI is installed
az bicep version

# Restore Bicep modules (optional, will auto-restore during deployment)
az bicep restore --file platform/**/*.bicep
```

### Configuration Files

Ensure these configuration files exist and are populated:

- `subscription-vending/config/subscriptions.json` - Subscription definitions
- `platform/logging/config/logging.prod.json` - Logging configuration
- `platform/connectivity/config/ipam.json` - IPAM configuration
- `platform/connectivity/config/subnet-blueprints.json` - Subnet profiles
- `platform/connectivity/config/connectivity.prod.json` - Connectivity configuration
- `platform/policies/archetypes/*/prod.json` - Policy archetypes

---

## Deployment Order

The deployment must follow this sequence to ensure dependencies are met:

```
Phase 0: Guardrails & Contracts (Foundation)
  ↓
Phase 1: Central Logging Backbone
  ↓
Phase 2: IP Governance & Subnet Standards
  ↓
Phase 3: vWAN Secure Hub
  ↓
Phase 9: Policy Enforcement (No Drift)
  ↓
Phase 4: Spoke VNets (Landing Zones)
  ↓
Phase 5: Private DNS & Private Endpoints
  ↓
Phase 6: Ingress Architecture (WAF)
  ↓
Phase 7: Non-HTTP Ingress (DNAT)
```

**Critical Dependency Chain:**
- Phase 1 → Phase 3 (LAW ID required for diagnostics)
- Phase 1 → Phase 4 (LAW ID required for diagnostics)
- Phase 3 → Phase 4 (vHub connection required)
- Phase 3 → Phase 6 (vHub connection required)
- Phase 5 → Phase 4 (Private DNS zones required for PE)

---

## Detailed Deployment Steps

### Phase 0: Guardrails & Contracts (Foundation)

No action required. Contracts referenced by other modules.

---

### Phase 1: Central Logging Backbone

```powershell
cd platform/logging/scripts
./deploy-logging.ps1
```

Validation:
```bash
az monitor log-analytics workspace show --subscription rai-platform-logging-prod-01 --resource-group rg-rai-prod-aue-logging-01 --workspace-name law-rai-prod-aue-platform-01 --query "id" -o tsv
```

---

### Phase 2: IP Governance & Subnet Standards

Verify IPAM configuration exists:
```bash
cat platform/connectivity/config/ipam.json | jq '.ipamConfig'
```

IPAM allocation happens automatically during Phase 3/4 deployments.

---

### Phase 3: vWAN Secure Hub

Full deployment (default):
```powershell
cd platform/connectivity/scripts
./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01"
```

Stage-by-stage deployment:
```powershell
cd platform/connectivity/scripts

# Stage 1: Hub Core (vWAN + vHub)
./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01" -DeployAll:$false -DeployHubCore

# Stage 2: Firewall Policy
./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01" -DeployAll:$false -DeployFirewallPolicy

# Stage 3: Azure Firewall
./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01" -DeployAll:$false -DeployFirewall

# Stage 4: Routing Intent
./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01" -DeployAll:$false -DeployRouting

# Stage 5: Private DNS Zones
./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01" -DeployAll:$false -DeployPrivateDns
```

Validation:
```powershell
az network vwan show --subscription rai-platform-connectivity-prod-01 --resource-group rg-core-network-australiaeast-001 --name vwan-australiaeast
az network vhub show --subscription rai-platform-connectivity-prod-01 --resource-group rg-core-network-australiaeast-001 --name vhub-australiaeast-001
az network firewall show --subscription rai-platform-connectivity-prod-01 --resource-group rg-core-network-australiaeast-001 --name fw-vhub-australiaeast-001-001
```

---

### Phase 9: Policy Enforcement (No Drift)

Deploy/update initiatives (if needed):
```bash
cd platform/policies/scripts
./deploy-initiative.sh network-baseline rai australiaeast
./deploy-initiative.sh data-protection-baseline rai australiaeast
./deploy-initiative.sh storage-baseline rai australiaeast
./deploy-initiative.sh monitoring-baseline rai australiaeast
```

Assign archetypes to management groups:
```bash
# Platform-Connectivity
./assign-mg-archetype.sh platform-connectivity australiaeast platform-connectivity-prod ../archetypes/platform-connectivity/prod.json ../assignments/mg/platform-connectivity.bicep

# Platform-Identity
./assign-mg-archetype.sh platform-identity australiaeast platform-identity-prod ../archetypes/platform-identity/prod.json ../assignments/mg/platform-identity.bicep

# Platform-Management
./assign-mg-archetype.sh platform-management australiaeast platform-management-prod ../archetypes/platform-management/prod.json ../assignments/mg/platform-management.bicep

# Platform-Logging
./assign-mg-archetype.sh platform-logging australiaeast platform-logging-prod ../archetypes/platform-logging/prod.json ../assignments/mg/platform-logging.bicep

# Corp Landing Zones
./assign-mg-archetype.sh corp australiaeast corp-prod ../archetypes/corp/prod.json ../assignments/mg/corp.bicep

# Online Landing Zones
./assign-mg-archetype.sh online australiaeast online-prod ../archetypes/online/prod.json ../assignments/mg/online.bicep
```

Validation:
```bash
az policy assignment list --scope /providers/Microsoft.Management/managementGroups/platform-connectivity --output table
az policy state list --resource "/providers/Microsoft.Management/managementGroups/corp" --filter "complianceState eq 'NonCompliant'" --output table
```

---

### Phase 4: Spoke VNets (Landing Zones)

```powershell
cd platform/connectivity/scripts
./deploy-connectivity.ps1 -SubscriptionId "rai-lending-core-prod-01"
```

Validation:
```bash
az network vnet show --subscription rai-lending-core-prod-01 --resource-group rg-lending-core-network-australiaeast-001 --name vnet-lending-core-australiaeast-001
az network vhub connection list --subscription rai-platform-connectivity-prod-01 --resource-group rg-core-network-australiaeast-001 --vhub-name vhub-australiaeast-001 --output table
```

---

### Phase 5: Private DNS & Private Endpoints

DNS Zones deployed during Phase 3 if enabled in `connectivity.prod.json`.

Private Endpoint example:
```powershell
az deployment group create --resource-group rg-lending-core-network-australiaeast-001 --template-file workloads/bicep/private-endpoint.bicep --parameters privateEndpointName=pe-kv-lending-core-01 targetResourceId=/subscriptions/.../vaults/kv-rai-prod-aue-lending-01 groupIds='["vault"]' subnetResourceId=/subscriptions/.../subnets/snet-private-endpoints privateDnsZoneResourceIds='["/subscriptions/.../privatelink.vaultcore.azure.net"]'
```

---

### Phase 6: Ingress Architecture (WAF)

```powershell
cd platform/connectivity/scripts
./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01"
```

Validation: See [Validation Checklist - WAF Ingress](#waf-ingress-works)

---

### Phase 7: Non-HTTP Ingress (DNAT)

Configure `platform/connectivity/config/inbound-services.prod.json`. DNAT rules deployed automatically with firewall policy (Phase 3).

Validation: See [Validation Checklist - DNAT Works](#dnat-works-if-enabled)

---

## Validation Checklist

### 1. Firewall Logs in LAW
```bash
# Get Firewall resource ID
FIREWALL_ID=$(az network firewall show \
  --subscription rai-platform-connectivity-prod-01 \
  --resource-group rg-core-network-australiaeast-001 \
  --name azfw-australiaeast-001 \
  --query "id" -o tsv)

# Check diagnostic settings
az monitor diagnostic-settings list \
  --resource $FIREWALL_ID \
  --output table

# Verify logs are flowing (query LAW)
LAW_ID=$(az monitor log-analytics workspace show \
  --subscription rai-platform-logging-prod-01 \
  --resource-group rg-rai-prod-aue-logging-01 \
  --workspace-name law-rai-prod-aue-platform-01 \
  --query "customerId" -o tsv)

# Query Firewall logs (requires Azure Portal or KQL query)
# Go to Azure Portal > Log Analytics Workspace > Logs
# Run query:
# AzureDiagnostics
# | where ResourceType == "AZUREFIREWALLS"
# | where TimeGenerated > ago(1h)
# | summarize count() by Category
```

Expected: Diagnostic settings configured, logs appear in LAW within 5-15 minutes

---

### 2. Egress IP Verification
```bash
# Get Firewall Public IP
FIREWALL_PUBLIC_IP=$(az network firewall show \
  --subscription rai-platform-connectivity-prod-01 \
  --resource-group rg-core-network-australiaeast-001 \
  --name azfw-australiaeast-001 \
  --query "ipConfigurations[0].publicIpAddress.id" -o tsv)

FIREWALL_IP=$(az network public-ip show \
  --ids $FIREWALL_PUBLIC_IP \
  --query "ipAddress" -o tsv)

echo "Firewall Public IP: $FIREWALL_IP"

# Verify route table is associated with spoke VNet connection
az network vhub connection show \
  --subscription rai-platform-connectivity-prod-01 \
  --resource-group rg-core-network-australiaeast-001 \
  --vhub-name vhub-australiaeast-001 \
  --name vnet-rai-prod-aue-corp-01-connection \
  --query "routingConfiguration.associatedRouteTable.id" -o tsv
```

From spoke VM: `curl -s https://api.ipify.org` (should return Firewall Public IP)

---

### 3. PE DNS Resolution
```bash
# Get Private Endpoint NIC IP
PE_NIC_ID=$(az network private-endpoint show \
  --resource-group rg-lending-core-network-australiaeast-001 \
  --name pe-kv-lending-core-01 \
  --query "networkInterfaces[0].id" -o tsv)

PE_IP=$(az network nic show \
  --ids $PE_NIC_ID \
  --query "ipConfigurations[0].privateIpAddress" -o tsv)

echo "Private Endpoint IP: $PE_IP"

# Verify DNS zone exists
az network private-dns zone show \
  --subscription rai-platform-connectivity-prod-01 \
  --resource-group rg-core-network-australiaeast-001 \
  --name privatelink.vaultcore.azure.net \
  --query "id" -o tsv

# Verify VNet link exists
az network private-dns link vnet list \
  --subscription rai-platform-connectivity-prod-01 \
  --resource-group rg-core-network-australiaeast-001 \
  --zone-name privatelink.vaultcore.azure.net \
  --output table

From spoke VM: `nslookup kv-rai-prod-aue-lending-01.vaultcore.azure.net` (should resolve to private endpoint IP)

---

### 4. WAF Ingress Works
```bash
# Get Application Gateway Public IP
APPGW_PUBLIC_IP=$(az network application-gateway show \
  --subscription rai-platform-connectivity-prod-01 \
  --resource-group rg-core-network-australiaeast-001 \
  --name agw-rai-prod-aue-ingress-01 \
  --query "frontendIpConfigurations[0].publicIpAddress.id" -o tsv)

APPGW_IP=$(az network public-ip show \
  --ids $APPGW_PUBLIC_IP \
  --query "ipAddress" -o tsv)

echo "Application Gateway Public IP: $APPGW_IP"

# Verify WAF Policy is attached
az network application-gateway show \
  --subscription rai-platform-connectivity-prod-01 \
  --resource-group rg-core-network-australiaeast-001 \
  --name agw-rai-prod-aue-ingress-01 \
  --query "firewallPolicy.id" -o tsv

Test connectivity: `curl -v http://$APPGW_IP`

---

### 5. DNAT Works (if enabled)
```bash
# Get Firewall Public IP
FIREWALL_IP=$(az network public-ip show \
  --ids $(az network firewall show \
    --subscription rai-platform-connectivity-prod-01 \
    --resource-group rg-core-network-australiaeast-001 \
    --name azfw-australiaeast-001 \
    --query "ipConfigurations[0].publicIpAddress.id" -o tsv) \
  --query "ipAddress" -o tsv)

echo "Firewall Public IP: $FIREWALL_IP"

# Verify DNAT rules exist in Firewall Policy
az network firewall policy rule-collection-group show \
  --subscription rai-platform-connectivity-prod-01 \
  --resource-group rg-core-network-australiaeast-001 \
  --firewall-policy-name fwpolicy-australiaeast-001 \
  --name IngressNonHttp \
  --query "properties.ruleCollections[?ruleCollectionType=='FirewallPolicyNatRuleCollection'].rules" -o json

Test DNAT: `ssh user@$FIREWALL_IP -p 22` (from allowed source IP)

---

### 6. Peering Denied by Policy
```bash
# Check policy assignment exists
az policy assignment list \
  --scope /providers/Microsoft.Management/managementGroups/corp \
  --filter "contains(displayName, 'network-baseline')" \
  --output table

# Check policy compliance state
az policy state list \
  --resource "/providers/Microsoft.Management/managementGroups/corp" \
  --filter "policyDefinitionReferenceId eq 'DenyVNetPeering' and complianceState eq 'NonCompliant'" \
  --output table

Test peering creation (should be denied by policy)

---

## Troubleshooting

### Common Issues

#### Log Analytics Workspace Not Found
- Verify Phase 1 completed
- Check subscription: `rai-platform-logging-prod-01`

#### vHub Connection Fails
- Ensure Phase 3 completed before Phase 4
- Verify hub subscription ID is correct

#### Route Table Not Associated
- Verify hub connection has routingConfiguration set
- Verify route table contains `0.0.0.0/0` route to firewall

#### Private DNS Resolution Fails
- Verify DNS zone exists and is linked to VNet
- Ensure VNet DNS servers point to Azure DNS (168.63.129.16)

#### Policy Denial Unexpected
- Check policy assignments on management group
- Review policy effects in archetype JSON

---

## Next Steps

1. Configure monitoring alerts in Log Analytics Workspace
2. Document policy exemptions or deviations
3. Update network diagrams and architecture docs
4. Train operations team on monitoring and troubleshooting

---

## Quick Reference

### Key Resource Names (Production)

| Resource Type | Subscription | Resource Group | Name |
|--------------|--------------|----------------|------|
| Log Analytics Workspace | rai-platform-logging-prod-01 | rg-rai-prod-aue-logging-01 | law-rai-prod-aue-platform-01 |
| Virtual WAN | rai-platform-connectivity-prod-01 | rg-core-network-australiaeast-001 | vwan-australiaeast |
| Virtual Hub | rai-platform-connectivity-prod-01 | rg-core-network-australiaeast-001 | vhub-australiaeast-001 |
| Azure Firewall | rai-platform-connectivity-prod-01 | rg-core-network-australiaeast-001 | azfw-australiaeast-001 |
| Application Gateway WAF | rai-platform-connectivity-prod-01 | rg-core-network-australiaeast-001 | agw-rai-prod-aue-ingress-01 |


### Key Script Locations

- Logging: `platform/logging/scripts/deploy-logging.ps1`
- Connectivity: `platform/connectivity/scripts/deploy-connectivity.ps1`
- Policies: `platform/policies/scripts/deploy-initiative.sh` and `platform/policies/scripts/assign-mg-archetype.sh`

---

## Cleanup

```powershell
cd platform/connectivity/scripts
./cleanup-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01"
```

Or manually:
```powershell
az group delete --name "rg-core-network-australiaeast-001" --subscription "rai-platform-connectivity-prod-01" --yes
```

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Maintained By**: Platform Engineering Team
