#!/usr/bin/env bash
set -euo pipefail

LOCATION="${1:-australiaeast}"
ARCHETYPE_NAME="${2:-corp-prod}"
ARCHETYPE_FILE="${3:-platform/policies/archetypes/corp/prod.json}"
MODULE="${4:-platform/policies/assignments/sub/archetype-assignment.bicep}"

az deployment sub create \
  --location "$LOCATION" \
  --template-file "$MODULE" \
  --parameters archetypeName="$ARCHETYPE_NAME" archetype=@"$ARCHETYPE_FILE"
