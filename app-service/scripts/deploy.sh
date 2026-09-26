#!/usr/bin/env bash
# Deploy the App Service Bicep template.
#
# Usage:
#   ./scripts/deploy.sh -g <resource-group> -p <params-file> [-l <location>] [-s <subscription>] [--what-if]
#
# Example:
#   ./scripts/deploy.sh -g rg-myapp-dev -l eastus -p parameters/dev.bicepparam --what-if
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/../main.bicep"

RESOURCE_GROUP=""
PARAMS_FILE=""
LOCATION=""
SUBSCRIPTION=""
WHAT_IF=false

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    -p|--parameters)     PARAMS_FILE="$2"; shift 2 ;;
    -l|--location)       LOCATION="$2"; shift 2 ;;
    -s|--subscription)   SUBSCRIPTION="$2"; shift 2 ;;
    --what-if)           WHAT_IF=true; shift ;;
    -h|--help)           usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[[ -z "$RESOURCE_GROUP" || -z "$PARAMS_FILE" ]] && usage
[[ -f "$PARAMS_FILE" ]] || { echo "Parameters file not found: $PARAMS_FILE" >&2; exit 1; }

command -v az >/dev/null || { echo "Azure CLI (az) is required: https://aka.ms/azure-cli" >&2; exit 1; }
az account show >/dev/null 2>&1 || az login >/dev/null

if [[ -n "$SUBSCRIPTION" ]]; then
  az account set --subscription "$SUBSCRIPTION"
fi
echo "Subscription: $(az account show --query name -o tsv)"

if [[ "$(az group exists --name "$RESOURCE_GROUP")" != "true" ]]; then
  [[ -z "$LOCATION" ]] && { echo "Resource group '$RESOURCE_GROUP' does not exist; pass -l <location> to create it." >&2; exit 1; }
  echo "Creating resource group $RESOURCE_GROUP in $LOCATION..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
fi

DEPLOYMENT_NAME="appservice-$(date +%Y%m%d%H%M%S)"

if $WHAT_IF; then
  az deployment group what-if \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$TEMPLATE" \
    --parameters "$PARAMS_FILE"
  exit 0
fi

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$TEMPLATE" \
  --parameters "$PARAMS_FILE" \
  --query "properties.outputs" \
  --output json
