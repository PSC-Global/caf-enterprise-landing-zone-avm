#!/usr/bin/env bash
set -euo pipefail

MG_ID="${1:-corp}"
LOCATION="${2:-australiaeast}"
ARCHETYPE_NAME="${3:-corp-prod}"
ARCHETYPE_FILE="${4:-platform/policies/archetypes/corp/prod.json}"
MODULE="${5:-platform/policies/assignments/mg/corp.bicep}"

az deployment mg create \
  --management-group-id "$MG_ID" \
  --location "$LOCATION" \
  --template-file "$MODULE" \
  --parameters archetypeName="$ARCHETYPE_NAME" archetype=@"$ARCHETYPE_FILE"
