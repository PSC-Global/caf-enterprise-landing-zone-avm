#!/usr/bin/env bash
set -eo pipefail

# Delete assignments for each MG (including parent scopes used for archetypes)
for MG in rai corp online platform platform-connectivity platform-identity platform-logging platform-management landing-zones; do
  echo "🗑️ Deleting assignments from $MG..."
  
  az policy assignment list --scope "/providers/Microsoft.Management/managementGroups/$MG" --query "[].name" -o tsv | \
  while read assignment_name; do
    az policy assignment delete --name "$assignment_name" --scope "/providers/Microsoft.Management/managementGroups/$MG"
    echo "  ✓ Deleted assignment: $assignment_name"
  done
done

echo "✅ All assignments deleted"
echo ""

# Delete all custom policy set definitions (initiatives) from RAI MG
echo "🗑️ Deleting initiatives from rai..."

INITIATIVES=(
  "asset-management-baseline"
  "backup-baseline"
  "compute-baseline"
  "data-protection-baseline"
  "devops-baseline"
  "governance-baseline"
  "identity-baseline"
  "monitoring-baseline"
  "misc-baseline"
  "network-baseline"
  "defender-baseline"
  "storage-baseline"
)

for INITIATIVE in "${INITIATIVES[@]}"; do
  az policy set-definition delete --name "$INITIATIVE" --management-group rai
  echo "  ✓ Deleted initiative: $INITIATIVE"
done

echo "✅ All initiatives deleted"
echo ""
echo "🎉 Complete cleanup done! Ready for end-to-end test deployment."