#!/usr/bin/env bash
# Deploy all ASB domain initiatives to tenant root management group
set -eo pipefail

MG_ID="${1:-rai}"
LOCATION="${2:-australiaeast}"
DOMAIN_FILTER="${3:-}"

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "🚀 Deploying ASB domain initiative(s) to MG: $MG_ID (location: $LOCATION)"
echo "📂 Repository root: $REPO_ROOT"
echo ""

# Function to get initiative filename for a domain
get_initiative_name() {
  case "$1" in
    "asset-management") echo "asset-management-initiative" ;;
    "backup-recovery") echo "backup-initiative" ;;
    "compute") echo "compute-initiative" ;;
    "data-protection") echo "data-protection-initiative" ;;
    "devops") echo "devops-initiative" ;;
    "governance") echo "governance-initiative" ;;
    "identity") echo "identity-initiative" ;;
    "logging-monitoring") echo "monitoring-initiative" ;;
    "miscellaneous") echo "misc-initiative" ;;
    "network") echo "network-initiative" ;;
    "posture-compliance") echo "defender-initiative" ;;
    "storage") echo "storage-initiative" ;;
    *) echo "$1-initiative" ;;
  esac
}

# Map domain to expected initiative (policySetDefinition) name
get_baseline_psd_name() {
  case "$1" in
    "asset-management") echo "asset-management-baseline" ;;
    "backup-recovery") echo "backup-baseline" ;;
    "compute") echo "compute-baseline" ;;
    "data-protection") echo "data-protection-baseline" ;;
    "devops") echo "devops-baseline" ;;
    "governance") echo "governance-baseline" ;;
    "identity") echo "identity-baseline" ;;
    "logging-monitoring") echo "monitoring-baseline" ;;
    "miscellaneous") echo "misc-baseline" ;;
    "network") echo "network-baseline" ;;
    "posture-compliance") echo "defender-baseline" ;;
    "storage") echo "storage-baseline" ;;
    *) echo "$1-baseline" ;;
  esac
}

# Domain list
DOMAINS=(
  "asset-management"
  "backup-recovery"
  "compute"
  "data-protection"
  "devops"
  "governance"
  "identity"
  "logging-monitoring"
  "miscellaneous"
  "network"
  "posture-compliance"
  "storage"
)

# If a domain filter is provided (e.g., "data-protection" or "compute,network"), override the list
if [ -n "$DOMAIN_FILTER" ] && [ "$DOMAIN_FILTER" != "all" ]; then
  IFS=',' read -r -a DOMAINS <<< "$DOMAIN_FILTER"
fi

echo "📚 Domains to deploy: ${DOMAINS[*]}"

# Deploy each initiative
for DOMAIN in "${DOMAINS[@]}"; do
  INITIATIVE=$(get_initiative_name "$DOMAIN")
  TEMPLATE="$REPO_ROOT/platform/policies/definitions/${DOMAIN}/${INITIATIVE}.bicep"
  
  echo "📦 Deploying ${DOMAIN}..."
  
  if [ ! -f "$TEMPLATE" ]; then
    echo "❌ Error: Template not found: $TEMPLATE"
    exit 1
  fi
  # Use a stable deployment name for subsequent checks (avoid recomputing the timestamp)
  DEPLOYMENT_NAME="deploy-${DOMAIN}-$(date +%Y%m%d-%H%M%S)"

  # Create without waiting to avoid transient DeploymentNotFound during initial poll
  az deployment mg create \
    --management-group-id "$MG_ID" \
    --location "$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$TEMPLATE" \
    --only-show-errors \
    --no-wait \
    --output none

  echo "⏳ Verifying deployment record: $DEPLOYMENT_NAME"
  # Retry 'show' multiple times in case of eventual consistency on MG deployments
  SHOW_OK=false
  for i in {1..15}; do
    if az deployment mg show --management-group-id "$MG_ID" --name "$DEPLOYMENT_NAME" --only-show-errors >/dev/null 2>&1; then
      SHOW_OK=true
      break
    fi
    sleep 4
  done

  if [ "$SHOW_OK" = true ]; then
    STATE=$(az deployment mg show --management-group-id "$MG_ID" --name "$DEPLOYMENT_NAME" --query properties.provisioningState -o tsv || echo "Unknown")
    echo "✅ ${DOMAIN} deployment recorded (state: ${STATE})"
  else
    echo "⚠️  Could not read deployment '$DEPLOYMENT_NAME' at MG '$MG_ID'."
    echo "   Common causes:"
    echo "   - Mismatch in management group scope (current: $MG_ID)"
    echo "   - Insufficient RBAC to read MG deployments (need Management Group Contributor/Owner)"
    echo "   - Transient propagation delay (try again)"
    echo "   Tip: az account management-group show -n $MG_ID >/dev/null && echo 'MG exists' || echo 'MG not found'"
  fi

  # Additionally verify the policy set definition exists at the MG scope
  PSD_NAME=$(get_baseline_psd_name "$DOMAIN")
  if az policy set-definition show --management-group "$MG_ID" --name "$PSD_NAME" >/dev/null 2>&1; then
    echo "✅ Policy Set Definition present: $PSD_NAME"
  else
    echo "❌ Policy Set Definition not found yet: $PSD_NAME"
    echo "   It may still be provisioning. Try:\n     az policy set-definition show --management-group $MG_ID --name $PSD_NAME -o jsonc"
  fi

  sleep 1
  echo ""
done

echo "🎉 Requested initiatives deployed successfully to MG: $MG_ID"
echo ""
echo "📊 Verify deployment:"
echo "   # Option A: List all custom initiatives at scope"
echo "   az policy set-definition list --management-group $MG_ID --query \"[?policyType=='Custom'].{Name:name, DisplayName:displayName}\" -o table"
echo "   # Option B: Filter to this framework's names (baseline suffix)"
echo "   az policy set-definition list --management-group $MG_ID --query \"[?contains(name, '-baseline')].{Name:name, DisplayName:displayName}\" -o table"

