#!/bin/bash
# Deploy a regulatory compliance initiative to a subscription

set -e

# Check arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <subscription-id> <compliance-framework>"
    echo ""
    echo "Available frameworks:"
    echo "  iso27001        - ISO 27001:2013"
    echo "  soc2            - SOC 2 Type 2"
    echo "  mcsb            - Microsoft Cloud Security Benchmark"
    echo "  pcidss          - PCI DSS 4.0"
    echo "  ism-protected   - Australian Government ISM PROTECTED"
    echo ""
    echo "Example: $0 12345678-1234-1234-1234-123456789012 iso27001"
    exit 1
fi

SUBSCRIPTION_ID=$1
FRAMEWORK=$2
CONFIG_FILE="../compliance/configs/${FRAMEWORK}.json"

# Validate config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Compliance framework '${FRAMEWORK}' not found"
    echo "   Expected config file: ${CONFIG_FILE}"
    exit 1
fi

# Read config
POLICY_SET_ID=$(jq -r '.policySetDefinitionId' "$CONFIG_FILE")
DISPLAY_NAME=$(jq -r '.displayName' "$CONFIG_FILE")
FRAMEWORK_NAME=$(jq -r '.framework' "$CONFIG_FILE")

echo "📋 Deploying Compliance Framework"
echo "   Framework: ${FRAMEWORK_NAME}"
echo "   Subscription: ${SUBSCRIPTION_ID}"
echo "   Mode: Audit Only (DoNotEnforce)"
echo ""

# Deploy compliance assignment
az deployment sub create \
  --subscription "$SUBSCRIPTION_ID" \
  --location australiaeast \
  --name "deploy-${FRAMEWORK}-compliance-$(date +%Y%m%d-%H%M%S)" \
  --template-file ../compliance/assignments/compliance-assignment.bicep \
  --parameters \
    complianceFramework="$FRAMEWORK" \
    policySetDefinitionId="$POLICY_SET_ID" \
    displayName="$DISPLAY_NAME" \
    assignmentName="${FRAMEWORK}-compliance" \
    enforcementMode="DoNotEnforce"

echo ""
echo "✅ Compliance framework deployed successfully"
echo ""
echo "📊 View compliance status:"
echo "   Azure Portal → Policy → Compliance"
echo "   Filter by assignment: ${FRAMEWORK}-compliance"
echo ""
echo "⏳ Note: Initial compliance scan takes 15-30 minutes"
