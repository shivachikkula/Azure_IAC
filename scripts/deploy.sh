#!/usr/bin/env bash
# Deploy any template in this repo at subscription scope.
# The template comes from the parameters file's "using" line; the resource group
# name and location are read from its resourceGroupName and location parameters.
#
# Usage:
#   ./scripts/deploy.sh -p <params-file> [-s <subscription>] [--what-if]
#
# Example:
#   ./scripts/deploy.sh -p storage-account/parameters/dev.bicepparam --what-if
set -euo pipefail

PARAMS_FILE=""
SUBSCRIPTION=""
WHAT_IF=false

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--parameters)     PARAMS_FILE="$2"; shift 2 ;;
    -s|--subscription)   SUBSCRIPTION="$2"; shift 2 ;;
    --what-if)           WHAT_IF=true; shift ;;
    -h|--help)           usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[[ -z "$PARAMS_FILE" ]] && usage
[[ -f "$PARAMS_FILE" ]] || { echo "Parameters file not found: $PARAMS_FILE" >&2; exit 1; }

# Resolve the template from the parameters file's "using '<path>'" line (relative to the file).
USING=$(sed -nE "s/^using '([^']+)'.*/\1/p" "$PARAMS_FILE" | head -n 1)
[[ -n "$USING" ]] || { echo "No \"using '<template>'\" line in $PARAMS_FILE" >&2; exit 1; }
TEMPLATE="$(cd "$(dirname "$PARAMS_FILE")" && cd "$(dirname "$USING")" && pwd)/$(basename "$USING")"
[[ -f "$TEMPLATE" ]] || { echo "Template not found: $TEMPLATE" >&2; exit 1; }

command -v az >/dev/null || { echo "Azure CLI (az) is required: https://aka.ms/azure-cli" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required: https://jqlang.github.io/jq/" >&2; exit 1; }
az account show >/dev/null 2>&1 || az login >/dev/null

if [[ -n "$SUBSCRIPTION" ]]; then
  az account set --subscription "$SUBSCRIPTION"
fi
echo "Subscription: $(az account show --query name -o tsv)"

# Read the resource group and location from the parameters file.
PARAMS_JSON="$(mktemp)"
trap 'rm -f "$PARAMS_JSON"' EXIT
az bicep build-params --file "$PARAMS_FILE" --outfile "$PARAMS_JSON"
RESOURCE_GROUP=$(jq -r '.parameters.resourceGroupName.value // empty' "$PARAMS_JSON")
LOCATION=$(jq -r '.parameters.location.value // empty' "$PARAMS_JSON")
[[ -n "$RESOURCE_GROUP" && -n "$LOCATION" ]] || { echo "Set resourceGroupName and location in $PARAMS_FILE" >&2; exit 1; }
echo "Template: $TEMPLATE"
echo "Resource group: $RESOURCE_GROUP ($LOCATION)"

DEPLOYMENT_NAME="$(basename "$(dirname "$TEMPLATE")")-$(date +%Y%m%d%H%M%S)"

if $WHAT_IF; then
  az deployment sub what-if \
    --location "$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$TEMPLATE" \
    --parameters "$PARAMS_FILE"
  exit 0
fi

az deployment sub create \
  --location "$LOCATION" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$TEMPLATE" \
  --parameters "$PARAMS_FILE" \
  --query "properties.outputs" \
  --output json
