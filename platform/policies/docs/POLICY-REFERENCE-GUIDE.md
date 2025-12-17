# Policy Reference Guide for Cloud Engineers

Quick reference guide to understand what policies are enforced in each management group. Use this to know what will be blocked/audited before deploying resources.

---

## Quick Decision Tree: Which MG Should I Use?

```
Is your application internet-facing?
├─ YES → Use Online MG
│   ├─ Production traffic? → online-prod (strict enforcement)
│   └─ Dev/Test? → online-nonprod (audit only)
│
└─ NO → Use Corp MG
    ├─ Production? → corp-prod (strict enforcement)
    └─ Dev/Test? → corp-nonprod (audit only)
```

---

## Policy Enforcement Summary

| Management Group | Enforcement Level | When Things Get Blocked |
|-----------------|-------------------|-------------------------|
| **corp-prod** | 🔴 **Strict** | Missing managed identity, public IPs, unencrypted storage, no HTTPS |
| **corp-nonprod** | 🟡 **Lenient** | Nothing blocked, only warnings in compliance dashboard |
| **online-prod** | 🔴 **Strict** | Missing managed identity, no HTTPS, unencrypted storage |
| **online-nonprod** | 🟡 **Lenient** | Nothing blocked, only warnings |
| **platform-*** | 🔴 **Very Strict** | Platform teams only; contact Platform Engineering |

---

## Corp MG: Internal Applications (No Public Access)

### Corp-Prod: What You CANNOT Deploy ❌

#### Identity Violations
- ❌ Virtual machines without system-assigned managed identity
- ❌ App Services without managed identity enabled
- ❌ Function Apps without managed identity enabled

**Fix**:
```bash
# VMs: Add --assign-identity
az vm create --name myvm --assign-identity [system]

# App Service: Add --assign-identity
az webapp create --name myapp --assign-identity [system]

# In Terraform:
resource "azurerm_linux_virtual_machine" "example" {
  identity {
    type = "SystemAssigned"
  }
}
```

#### Network Violations
- ❌ VMs with public IP addresses
- ❌ Network interfaces with public IPs
- ❌ Subnets without Network Security Groups (NSG)
- ❌ NSGs with rules allowing 0.0.0.0/0 inbound (open to internet)

**Fix**:
```bash
# Deploy without public IP (default in Corp)
az vm create --name myvm --public-ip-address ""

# In Terraform:
resource "azurerm_linux_virtual_machine" "example" {
  # Do NOT add public_ip_address_id
  network_interface_ids = [azurerm_network_interface.example.id]
}

# Always attach NSG to subnet
az network nsg create --name myapp-nsg
az network vnet subnet update --vnet-name myvnet --name mysubnet --network-security-group myapp-nsg
```

#### Storage Violations
- ❌ Storage accounts allowing HTTP (non-HTTPS)
- ❌ Storage accounts with public blob access enabled
- ❌ Storage accounts without secure transfer (HTTPS only)

**Fix**:
```bash
# Always use HTTPS and disable public access
az storage account create \
  --name mystorageacct \
  --https-only true \
  --allow-blob-public-access false

# In Terraform:
resource "azurerm_storage_account" "example" {
  enable_https_traffic_only = true
  allow_nested_items_to_be_public = false
}
```

#### Compute Violations
- ❌ VMs without encryption at host
- ❌ VMs using non-approved SKUs (only Standard_D*, Standard_E* allowed)
- ❌ Unmanaged disks

**Fix**:
```bash
# Use approved SKUs
az vm create --size Standard_D2s_v3  # ✅ Allowed
az vm create --size Standard_B1s     # ❌ Blocked (B-series not approved for prod)

# In Terraform:
resource "azurerm_linux_virtual_machine" "example" {
  size = "Standard_D2s_v3"  # Use Standard_D or Standard_E series
}
```

#### Governance Violations
- ❌ Resources without required tags: `Environment`, `Owner`, `CostCenter`
- ❌ Resources in non-approved locations (only Australia East/Southeast allowed)

**Fix**:
```bash
# Always tag resources
az vm create \
  --name myvm \
  --tags Environment=prod Owner=myteam@company.com CostCenter=CC-1234

# Set allowed location
az group create --name myapp-rg --location australiaeast  # ✅
az group create --name myapp-rg --location eastus         # ❌ Blocked
```

---

### Corp-NonProd: What Gets Audited (Not Blocked) 🟡

Everything that's blocked in **corp-prod** is only **audited** in **corp-nonprod**:
- ✅ You CAN deploy VMs without managed identity (but you'll see compliance warnings)
- ✅ You CAN use public IPs for testing (but it's flagged)
- ✅ You CAN skip tags (but they'll show as non-compliant)
- ✅ You CAN use cheaper B-series VMs for dev/test

**When to use nonprod**:
- Development/testing environments
- Proof-of-concept work
- Temporary sandbox subscriptions
- Learning/training environments

---

## Online MG: Public-Facing Applications

### Online-Prod: What You CANNOT Deploy ❌

#### Same as Corp-Prod, EXCEPT:

✅ **Public IPs ARE allowed** (for load balancers, app gateways)
✅ **Controlled public storage access allowed** (for CDN, static websites)

#### What's Still Blocked:
- ❌ VM directly with public IP (use load balancer instead)
- ❌ Storage without HTTPS enforcement
- ❌ Missing managed identities
- ❌ Unencrypted data

**Typical online-prod architecture**:
```
Internet → Azure Front Door/App Gateway (public IP) 
    → Internal Load Balancer (private IP) 
        → VMs/App Services (no public IPs)
```

**Fix**:
```bash
# ✅ Allowed: Public IP on load balancer
az network lb create --name myapp-lb --public-ip-address myapp-pip

# ❌ Blocked: Public IP directly on VM
az vm create --name myvm --public-ip-address myvm-pip  # Blocked

# ✅ Allowed: Static website on storage (with HTTPS)
az storage account create \
  --name mycdnstorage \
  --https-only true \
  --allow-blob-public-access true \
  --public-network-access Enabled
```

---

### Online-NonProd: What Gets Audited 🟡

Same as **corp-nonprod** - all policies are audit-only:
- ✅ You can deploy directly with public IPs for testing
- ✅ You can skip managed identities temporarily
- ✅ You can use HTTP for local testing

---

## Common Deployment Scenarios

### Scenario 1: Deploying a Web Application

#### Corp-Prod (Internal Intranet App)
```bash
# 1. Create resource group in allowed location
az group create --name myapp-prod-rg --location australiaeast \
  --tags Environment=prod Owner=webteam@company.com CostCenter=CC-5678

# 2. Create App Service with managed identity + HTTPS
az appservice plan create --name myapp-plan --sku P1V2
az webapp create \
  --name myapp \
  --plan myapp-plan \
  --assign-identity [system] \
  --https-only true

# 3. Configure private endpoint (no public access)
az webapp update --name myapp --set publicNetworkAccess=Disabled
az network private-endpoint create \
  --name myapp-pe \
  --resource-group myapp-prod-rg \
  --vnet-name corp-vnet \
  --subnet app-subnet \
  --private-connection-resource-id $(az webapp show --name myapp --query id -o tsv) \
  --group-id sites \
  --connection-name myapp-pe-connection

# ✅ Deployment succeeds - all policies satisfied
```

#### Online-Prod (Public-Facing App)
```bash
# 1. Create resource group
az group create --name myapp-online-rg --location australiaeast \
  --tags Environment=prod Owner=webteam@company.com CostCenter=CC-5678

# 2. Create App Service with managed identity + HTTPS
az appservice plan create --name myapp-plan --sku P1V2
az webapp create \
  --name myapp \
  --plan myapp-plan \
  --assign-identity [system] \
  --https-only true

# 3. Configure public access (allowed in Online)
az webapp update --name myapp --set publicNetworkAccess=Enabled

# 4. (Optional) Add Azure Front Door for global distribution
az afd origin create --enabled-state Enabled --origin-host-header myapp.azurewebsites.net

# ✅ Deployment succeeds - public access allowed in Online MG
```

---

### Scenario 2: Deploying a SQL Database

#### Corp-Prod
```bash
# 1. Create SQL Server with managed identity
az sql server create \
  --name myapp-sqlserver \
  --resource-group myapp-prod-rg \
  --location australiaeast \
  --assign-identity \
  --enable-public-network false \
  --tags Environment=prod Owner=dataTeam@company.com CostCenter=CC-5678

# 2. Create database with encryption
az sql db create \
  --name myapp-db \
  --server myapp-sqlserver \
  --tier GeneralPurpose \
  --family Gen5 \
  --capacity 2

# 3. Configure private endpoint
az network private-endpoint create \
  --name sql-pe \
  --resource-group myapp-prod-rg \
  --vnet-name corp-vnet \
  --subnet data-subnet \
  --private-connection-resource-id $(az sql server show --name myapp-sqlserver --query id -o tsv) \
  --group-id sqlServer

# ✅ Compliant: Private access only, encrypted, managed identity
```

---

### Scenario 3: Deploying VMs for Application Servers

#### Corp-Prod
```bash
# 1. Create VM with managed identity, NO public IP
az vm create \
  --name myapp-vm \
  --resource-group myapp-prod-rg \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --assign-identity [system] \
  --public-ip-address "" \
  --vnet-name corp-vnet \
  --subnet app-subnet \
  --tags Environment=prod Owner=infrateam@company.com CostCenter=CC-5678

# 2. Access via Bastion or VPN (no public IP)
az network bastion create --name corp-bastion --vnet-name corp-vnet

# ✅ Compliant: Private access, managed identity, approved SKU
```

#### Corp-NonProd (Dev/Test)
```bash
# For quick testing - public IP allowed (but audited)
az vm create \
  --name myapp-dev-vm \
  --resource-group myapp-dev-rg \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --public-ip-sku Standard

# ⚠️ Deployment succeeds, but shows as non-compliant in dashboard
# Use for short-term dev work only
```

---

## Policy Compliance Dashboard

Check compliance before deploying:

```bash
# View all policy assignments in your subscription
az policy assignment list --query "[].{Name:displayName, Effect:parameters.effect.value}" -o table

# Check compliance state
az policy state list \
  --resource-group myapp-rg \
  --filter "complianceState eq 'NonCompliant'" \
  --query "[].{Resource:resourceId, Policy:policyDefinitionName, Reason:policyDefinitionAction}" \
  -o table

# Trigger manual policy scan (if recent deployment)
az policy state trigger-scan --resource-group myapp-rg
```

**Where to view compliance**:
1. Azure Portal → Policy → Compliance
2. Filter by subscription/resource group
3. Look for red "Non-compliant" badges before deploying

---

## Pre-Deployment Checklist

### Before Deploying to **Corp-Prod** or **Online-Prod**:

- [ ] Does every VM/App Service have `--assign-identity [system]`?
- [ ] Are you using approved VM sizes? (Standard_D*, Standard_E*)
- [ ] Is public IP usage justified? (Corp: NO, Online: Only for load balancers)
- [ ] Do all storage accounts have `--https-only true`?
- [ ] Do all storage accounts have `--allow-blob-public-access false` (Corp) or controlled (Online)?
- [ ] Are resources tagged with: `Environment`, `Owner`, `CostCenter`?
- [ ] Is location `australiaeast` or `australiasoutheast`?
- [ ] Do all subnets have NSGs attached?
- [ ] Are you using managed disks (not unmanaged)?

### Before Deploying to **NonProd**:

- [ ] Nothing will be blocked, but aim to follow prod patterns for easy promotion
- [ ] Check compliance dashboard weekly to catch policy violations early

---

## Getting Help

### Policy Violation Error Example

```
Code: RequestDisallowedByPolicy
Message: Resource 'myvm' was disallowed by policy.
Policy: identity-initiative
Policy Definition: Virtual machines should use managed identity
Effect: Deny
```

**How to fix**:
1. Read the "Policy Definition" name
2. Find it in this guide (search for "managed identity")
3. Apply the fix from the examples above
4. Redeploy

### Contact Points

- **Policy questions**: Platform Governance Team (governance@company.com)
- **Exemption requests**: Submit ticket to Security Operations
- **New MG/archetype requests**: Platform Engineering Team

### Common Exemption Scenarios

Some resources legitimately need policy exemptions:
- Legacy applications requiring public IPs (temporary exemption)
- Third-party integrations requiring specific configurations
- Pilot/POC projects (time-limited exemption)

**Request exemption**:
```bash
az policy exemption create \
  --name "myapp-public-ip-exemption" \
  --policy-assignment "corp-prod-network-initiative" \
  --exemption-category Waiver \
  --expires-on "2026-03-31" \
  --description "Public IP required for legacy SAP integration; migration planned Q1 2026"
```

---

## Quick Reference: Policy Effects

| Effect | What It Does | Use Case |
|--------|-------------|----------|
| **Audit** | Flags non-compliance, doesn't block | Dev/test environments, visibility |
| **Deny** | Blocks non-compliant resources | Production enforcement |
| **DeployIfNotExists** | Auto-creates missing configs | Diagnostic logs, backup policies |
| **Disabled** | Policy not evaluated | Temporarily disable specific checks |

---

## Terraform Example Templates

### Corp-Prod Compliant VM
```hcl
resource "azurerm_linux_virtual_machine" "corp_vm" {
  name                = "myapp-vm"
  resource_group_name = azurerm_resource_group.example.name
  location            = "australiaeast"
  size                = "Standard_D2s_v3"
  
  # ✅ Required: Managed identity
  identity {
    type = "SystemAssigned"
  }
  
  # ✅ Required: No public IP (omit public_ip_address_id)
  network_interface_ids = [azurerm_network_interface.example.id]
  
  # ✅ Required: Tags
  tags = {
    Environment = "prod"
    Owner       = "infrateam@company.com"
    CostCenter  = "CC-5678"
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
```

### Online-Prod Compliant App Service
```hcl
resource "azurerm_linux_web_app" "online_app" {
  name                = "myapp"
  resource_group_name = azurerm_resource_group.example.name
  location            = "australiaeast"
  service_plan_id     = azurerm_service_plan.example.id
  
  # ✅ Required: Managed identity
  identity {
    type = "SystemAssigned"
  }
  
  # ✅ Required: HTTPS only
  https_only = true
  
  # ✅ Allowed: Public access (Online MG permits this)
  public_network_access_enabled = true
  
  # ✅ Required: Tags
  tags = {
    Environment = "prod"
    Owner       = "webteam@company.com"
    CostCenter  = "CC-1234"
  }
  
  site_config {
    always_on = true
  }
}
```

---

## Summary Table: What's Blocked Where

| Resource Type | Corp-Prod | Corp-NonProd | Online-Prod | Online-NonProd |
|--------------|-----------|--------------|-------------|----------------|
| VM without managed identity | ❌ Blocked | ⚠️ Audited | ❌ Blocked | ⚠️ Audited |
| VM with public IP | ❌ Blocked | ⚠️ Audited | ❌ Blocked | ⚠️ Audited |
| Load balancer with public IP | ❌ Blocked | ⚠️ Audited | ✅ Allowed | ✅ Allowed |
| Storage without HTTPS | ❌ Blocked | ⚠️ Audited | ❌ Blocked | ⚠️ Audited |
| Storage with public blob access | ❌ Blocked | ⚠️ Audited | ✅ Allowed (controlled) | ✅ Allowed |
| Resources without tags | ❌ Blocked | ⚠️ Audited | ❌ Blocked | ⚠️ Audited |
| Resources outside Australia | ❌ Blocked | ⚠️ Audited | ❌ Blocked | ⚠️ Audited |
| B-series VMs | ❌ Blocked | ✅ Allowed | ❌ Blocked | ✅ Allowed |

---

**Remember**: When in doubt, deploy to **nonprod** first, check compliance dashboard, fix issues, then promote to **prod**.
