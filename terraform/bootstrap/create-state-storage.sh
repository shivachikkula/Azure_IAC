#!/usr/bin/env bash
# One-time setup: create the Azure Storage account that holds Terraform state, and write
# terraform/backend.hcl pointing at it. Commit backend.hcl afterwards.
#
# Usage:
#   ./terraform/bootstrap/create-state-storage.sh [-g <resource-group>] [-l <location>] [-s <subscription>]
#
# Defaults: resource group rg-tfstate in westus2. The storage account name gets a random suffix.
set -euo pipefail

RESOURCE_GROUP="rg-tfstate"
LOCATION="westus2"
SUBSCRIPTION=""
CONTAINER="tfstate"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g) RESOURCE_GROUP="$2"; shift 2 ;;
    -l) LOCATION="$2"; shift 2 ;;
    -s) SUBSCRIPTION="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_FILE="$SCRIPT_DIR/../backend.hcl"

command -v az >/dev/null || { echo "Azure CLI (az) is required: https://aka.ms/azure-cli" >&2; exit 1; }
az account show >/dev/null 2>&1 || az login >/dev/null
[[ -n "$SUBSCRIPTION" ]] && az account set --subscription "$SUBSCRIPTION"
echo "Subscription: $(az account show --query name -o tsv)"

if [[ -f "$BACKEND_FILE" ]]; then
  echo "$BACKEND_FILE already exists; delete it first to create a new state storage account." >&2
  exit 1
fi

ACCOUNT="sttfstate$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8)"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --tags managedBy=bootstrap purpose=terraform-state --output none
az storage account create \
  --name "$ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --https-only true \
  --allow-blob-public-access false \
  --tags managedBy=bootstrap purpose=terraform-state \
  --output none
# Keep old state versions and deleted state files recoverable
az storage account blob-service-properties update \
  --account-name "$ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 30 \
  --enable-container-delete-retention true --container-delete-retention-days 30 \
  --output none
az storage container create --name "$CONTAINER" --account-name "$ACCOUNT" --auth-mode login --output none 2>/dev/null \
  || az storage container create --name "$CONTAINER" --account-name "$ACCOUNT" --auth-mode key --output none

cat > "$BACKEND_FILE" <<HCL
# Terraform state storage, created by terraform/bootstrap/create-state-storage.sh.
# The state file key (<project>/<environment>.tfstate) is passed at init time.
resource_group_name  = "$RESOURCE_GROUP"
storage_account_name = "$ACCOUNT"
container_name       = "$CONTAINER"
HCL

echo
echo "State storage account: $ACCOUNT (resource group $RESOURCE_GROUP)"
echo "Wrote $BACKEND_FILE; commit it so the workflows and your team use the same state."
