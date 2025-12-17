# Regulatory Compliance Implementation Guide

This guide explains how to add regulatory compliance frameworks to your Azure Policy implementation for audit and compliance reporting.

## Overview

The policy framework supports **two layers**:

1. **ASB Domain Initiatives** (enforcement) → Enforces security controls via Deny/DINE policies
2. **Regulatory Compliance Initiatives** (audit) → Tracks compliance with specific regulatory frameworks

**Key principle**: Compliance initiatives are **audit-only** (DoNotEnforce mode). They don't block deployments—they only track compliance status for reporting.

---

## Supported Compliance Frameworks

### Top 5 Pre-Configured Frameworks

| Framework | Use Case | Policy Count | Config File |
|-----------|----------|--------------|-------------|
| **ISO 27001:2013** | Global information security standard | ~53 | `iso27001.json` |
| **SOC 2 Type 2** | SaaS/cloud service providers | ~81 | `soc2.json` |
| **Microsoft Cloud Security Benchmark** | Azure-native security baseline | ~200+ | `mcsb.json` |
| **PCI DSS 4.0** | Payment card processing | ~70 | `pcidss.json` |
| **Australian ISM PROTECTED** | AU government/enterprise | ~800+ | `ism-protected.json` |

### Additional Available Frameworks

Microsoft provides 20+ additional built-in compliance initiatives. See [Adding Custom Frameworks](#adding-custom-frameworks) below.

---

## Quick Start: Assign Compliance Framework

### Option 1: Using the Script (Recommended)

```bash
cd platform/policies/scripts

# Make script executable
chmod +x assign-compliance.sh

# Assign ISO 27001 to a subscription
./assign-compliance.sh <subscription-id> iso27001

# Assign SOC 2 to a subscription
./assign-compliance.sh <subscription-id> soc2

# Assign Microsoft Cloud Security Benchmark
./assign-compliance.sh <subscription-id> mcsb
```

### Option 2: Manual Deployment

```bash
# Load compliance config
FRAMEWORK="iso27001"
CONFIG=$(cat platform/policies/compliance/configs/${FRAMEWORK}.json)
POLICY_SET_ID=$(echo $CONFIG | jq -r '.policySetDefinitionId')
DISPLAY_NAME=$(echo $CONFIG | jq -r '.displayName')

# Deploy to subscription
az deployment sub create \
  --subscription <subscription-id> \
  --location australiaeast \
  --template-file platform/policies/compliance/assignments/compliance-assignment.bicep \
  --parameters \
    complianceFramework="$FRAMEWORK" \
    policySetDefinitionId="$POLICY_SET_ID" \
    displayName="$DISPLAY_NAME" \
    enforcementMode="DoNotEnforce"
```

---

## Deployment Scenarios

### Scenario 1: Subscription-Level Assignment (Common)

Assign compliance framework to a specific subscription:

```bash
# Example: Financial app requiring PCI-DSS
./assign-compliance.sh 12345678-1234-1234-1234-123456789012 pcidss

# Example: SaaS product requiring SOC 2
./assign-compliance.sh 87654321-4321-4321-4321-210987654321 soc2
```

**Result**: Only that subscription tracks compliance against the framework.

### Scenario 2: Multiple Frameworks per Subscription

Some subscriptions may need multiple compliance frameworks:

```bash
SUBSCRIPTION_ID="12345678-1234-1234-1234-123456789012"

# Assign ISO 27001 (global standard)
./assign-compliance.sh $SUBSCRIPTION_ID iso27001

# Assign SOC 2 (customer requirement)
./assign-compliance.sh $SUBSCRIPTION_ID soc2

# Assign Microsoft Cloud Security Benchmark (baseline)
./assign-compliance.sh $SUBSCRIPTION_ID mcsb
```

**Result**: Compliance dashboard shows status for all 3 frameworks.

### Scenario 3: Management Group-Level Assignment

For organization-wide compliance tracking, assign at MG level:

```bash
# Modify the Bicep template targetScope to 'managementGroup'
# Then deploy:
az deployment mg create \
  --management-group-id corp \
  --location australiaeast \
  --template-file platform/policies/compliance/assignments/compliance-assignment.bicep \
  --parameters complianceFramework="iso27001" \
    policySetDefinitionId="/providers/Microsoft.Authorization/policySetDefinitions/89c6cddc-1c73-4ac1-b19c-54d1a15a42f2" \
    displayName="ISO 27001:2013 Compliance" \
    enforcementMode="DoNotEnforce"
```

**Result**: All subscriptions under Corp MG inherit the compliance assignment.

---

## Viewing Compliance Status

### Azure Portal

1. Navigate to **Azure Policy** → **Compliance**
2. Filter by **Assignment name** (e.g., `iso27001-compliance`)
3. View compliance percentage and non-compliant resources
4. Click **Controls** tab to see compliance by control domain

### Azure CLI

```bash
# View compliance summary for a subscription
az policy state summarize \
  --subscription <subscription-id> \
  --filter "policyAssignmentName eq 'iso27001-compliance'"

# List non-compliant resources
az policy state list \
  --subscription <subscription-id> \
  --filter "policyAssignmentName eq 'iso27001-compliance' and complianceState eq 'NonCompliant'" \
  --query "[].{Resource:resourceId, Policy:policyDefinitionName}" \
  -o table

# Export compliance report
az policy state list \
  --subscription <subscription-id> \
  --filter "policyAssignmentName eq 'iso27001-compliance'" \
  --output json > iso27001-compliance-report.json
```

---

## Framework Selection Guide

### When to Use Each Framework

#### ISO 27001
- ✅ Global customers or operations
- ✅ Pursuing information security certification
- ✅ Contractual requirements for ISO compliance
- ✅ Baseline for international business

#### SOC 2 Type 2
- ✅ SaaS product companies
- ✅ Cloud service providers
- ✅ Handling customer data
- ✅ Third-party audits required

#### Microsoft Cloud Security Benchmark
- ✅ Azure-native organizations
- ✅ Using Microsoft Defender for Cloud
- ✅ Want comprehensive Azure security coverage
- ✅ Replacing Azure Security Benchmark (ASB)

#### PCI DSS 4.0
- ✅ E-commerce platforms
- ✅ Payment processing
- ✅ Storing/transmitting credit card data
- ✅ Financial services with card transactions

#### Australian ISM PROTECTED
- ✅ Australian government agencies
- ✅ Government contractors
- ✅ Handling AU government data
- ✅ Enterprise compliance in Australia

### Combining Frameworks

**Recommended combinations:**

```bash
# Global SaaS company
./assign-compliance.sh $SUB_ID iso27001  # International standard
./assign-compliance.sh $SUB_ID soc2      # Customer requirement
./assign-compliance.sh $SUB_ID mcsb      # Azure baseline

# Financial services (payments)
./assign-compliance.sh $SUB_ID pcidss    # Card data compliance
./assign-compliance.sh $SUB_ID soc2      # Service controls
./assign-compliance.sh $SUB_ID mcsb      # Azure security

# Australian government contractor
./assign-compliance.sh $SUB_ID ism-protected  # Gov requirement
./assign-compliance.sh $SUB_ID iso27001       # International ops
```

---

## Adding Custom Frameworks

To add additional Microsoft built-in compliance frameworks not in the top 5:

### Step 1: Find the Policy Set Definition ID

Visit [Azure Policy Samples](https://learn.microsoft.com/en-us/azure/governance/policy/samples/) and find your framework:

| Framework | Policy Set ID |
|-----------|---------------|
| NIST SP 800-53 Rev. 5 | `179d1daa-458f-4e47-8086-2a68d0d6c38f` |
| FedRAMP High | `d5264498-16f4-418a-b659-fa7ef418175f` |
| HIPAA HITRUST | `a169a624-5599-4385-a696-c8d643089fab` |
| CIS Azure Benchmark 2.0.0 | `06f19060-9e68-4070-92ca-f15cc126059e` |
| CMMC Level 3 | `b5629c75-5c77-4422-87b9-2509e680f8de` |

### Step 2: Create Config File

```bash
# Example: Adding NIST SP 800-53 Rev. 5
cat > platform/policies/compliance/configs/nist-80053-r5.json << EOF
{
  "framework": "NIST SP 800-53 Rev. 5",
  "policySetDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f",
  "displayName": "NIST SP 800-53 Rev. 5",
  "description": "This initiative includes policies that address a subset of NIST SP 800-53 Rev. 5 controls.",
  "recommendedScopes": ["managementGroup", "subscription"],
  "enforcementMode": "DoNotEnforce",
  "useCases": [
    "US federal government",
    "Government contractors",
    "Organizations requiring NIST compliance"
  ],
  "policyCount": "~800+ policies",
  "documentation": "https://learn.microsoft.com/en-us/azure/governance/policy/samples/nist-sp-800-53-r5"
}
EOF
```

### Step 3: Deploy Using Script

```bash
./assign-compliance.sh <subscription-id> nist-80053-r5
```

---

## Integration with Existing ASB Framework

### How Both Frameworks Work Together

```
┌─────────────────────────────────────────────────────────────┐
│ Subscription: corp-prod-payments                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Layer 1: ASB Domain Initiatives (Enforcement)               │
│   ├─ identity-initiative          → Deny                    │
│   ├─ network-initiative           → Deny                    │
│   ├─ storage-initiative           → Deny                    │
│   ├─ compute-baseline             → Deny                    │
│   └─ ... (8 more)                                           │
│                                                             │
│ Layer 2: Compliance Initiatives (Audit Only)                │
│   ├─ PCI DSS 4.0                  → Audit (DoNotEnforce)    │
│   ├─ ISO 27001                    → Audit (DoNotEnforce)    │
│   └─ SOC 2                        → Audit (DoNotEnforce)    │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Result:
✅ ASB initiatives enforce security (block non-compliant deployments)
✅ Compliance initiatives track compliance (report compliance %)
✅ No conflicts (compliance initiatives don't block anything)
```

### Example: VM Deployment

```bash
# Developer deploys VM without managed identity
az vm create --name testvm --image Ubuntu2204

# ASB identity-initiative (Deny effect):
❌ BLOCKED: "Virtual machines must use managed identity"

# Developer fixes and redeploys
az vm create --name testvm --image Ubuntu2204 --assign-identity [system]

# ASB identity-initiative:
✅ ALLOWED: VM has managed identity

# PCI DSS compliance initiative (Audit effect):
✅ PASS: VM complies with PCI DSS control 8.2.1

# ISO 27001 compliance initiative (Audit effect):
✅ PASS: VM complies with ISO 27001 A.9.2.1

# Compliance dashboard shows:
PCI DSS: 87% compliant (+1% from this VM)
ISO 27001: 92% compliant (+0.5% from this VM)
```

---

## Remediation

Some compliance policies support **DeployIfNotExists** (DINE) effects. To auto-remediate:

```bash
# Create remediation task for compliance initiative
az policy remediation create \
  --name "remediate-iso27001-$(date +%Y%m%d)" \
  --policy-assignment "iso27001-compliance" \
  --scope "/subscriptions/<subscription-id>"

# Monitor remediation progress
az policy remediation show \
  --name "remediate-iso27001-$(date +%Y%m%d)" \
  --scope "/subscriptions/<subscription-id>"
```

---

## Audit Reporting

### Generate Compliance Report for Auditors

```bash
# Export full compliance state
az policy state list \
  --subscription <subscription-id> \
  --filter "policyAssignmentName eq 'iso27001-compliance'" \
  --output json > iso27001-audit-report-$(date +%Y%m%d).json

# Export compliance summary
az policy state summarize \
  --subscription <subscription-id> \
  --filter "policyAssignmentName eq 'iso27001-compliance'" \
  --output json > iso27001-summary-$(date +%Y%m%d).json

# Export non-compliant resources only
az policy state list \
  --subscription <subscription-id> \
  --filter "policyAssignmentName eq 'iso27001-compliance' and complianceState eq 'NonCompliant'" \
  --output csv > iso27001-non-compliant-$(date +%Y%m%d).csv
```

### Continuous Compliance Monitoring

Set up automated compliance reporting:

```bash
# Add to CI/CD pipeline
#!/bin/bash
FRAMEWORKS=("iso27001" "soc2" "pcidss")

for framework in "${FRAMEWORKS[@]}"; do
  az policy state summarize \
    --subscription $SUBSCRIPTION_ID \
    --filter "policyAssignmentName eq '${framework}-compliance'" \
    --query "results.{Framework:'$framework', Compliant:resourceDetails.compliant, NonCompliant:resourceDetails.nonCompliant, CompliancePercentage:policyGroupDetails[0].complianceState}" \
    -o json >> compliance-report.json
done
```

---

## Best Practices

1. **Start with audit-only** - Always use `DoNotEnforce` mode for compliance initiatives
2. **Layer with ASB** - Use ASB for enforcement, compliance for reporting
3. **Subscription-level assignment** - Assign compliance frameworks at subscription level for granular control
4. **Multiple frameworks** - Assign multiple frameworks where needed (ISO + SOC + MCSB is common)
5. **Regular reporting** - Schedule weekly compliance reports to track progress
6. **Remediation cadence** - Run monthly remediation tasks for DINE policies
7. **Exemptions** - Document exemptions with expiration dates and business justification
8. **Version control configs** - Treat compliance configs as code; use Git tags

---

## Troubleshooting

### Issue: Compliance data not showing

**Solution**: Wait 15-30 minutes for initial scan, then trigger manual scan:
```bash
az policy state trigger-scan --subscription <subscription-id>
```

### Issue: Too many policies causing noise

**Solution**: Start with lighter frameworks first:
1. Microsoft Cloud Security Benchmark (~200 policies)
2. ISO 27001 (~53 policies)
3. Only add heavy frameworks (ISM PROTECTED: ~800) if required

### Issue: Conflicts between compliance and ASB

**Solution**: Ensure compliance initiatives use `DoNotEnforce`:
```bash
# Verify enforcement mode
az policy assignment show \
  --name "iso27001-compliance" \
  --scope "/subscriptions/<sub-id>" \
  --query "enforcementMode"
```

### Issue: Managed identity permissions

**Solution**: The compliance assignment module automatically grants Contributor. For custom permissions:
```bash
az role assignment create \
  --assignee <identity-principal-id> \
  --role "Policy Contributor" \
  --scope "/subscriptions/<sub-id>"
```

---

## Summary

✅ **5 frameworks pre-configured**: ISO 27001, SOC 2, MCSB, PCI-DSS, ISM PROTECTED
✅ **Easy deployment**: One script command per framework
✅ **Audit-only mode**: No impact on deployments
✅ **Works with ASB**: Enforcement + compliance reporting
✅ **Extensible**: Add any Microsoft built-in framework in 2 steps

**Next Steps**:
1. Identify which compliance frameworks you need
2. Deploy to test subscription first
3. Monitor compliance dashboard for 2 weeks
4. Expand to production subscriptions
5. Set up automated reporting for auditors
