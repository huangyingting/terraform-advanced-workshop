#!/usr/bin/env bash
set -euo pipefail

# Lab 9 prerequisite provisioning script
# Creates: Resource Group, Storage Account, Key Vault, ACR
# Outputs: lab9-prereqs.auto.tfvars containing resource IDs for Terraform variables
# Usage: (optionally export env vars first)
#   RG_NAME=lab9 LOCATION=southeastasia ./provision-prereqs.sh
# Idempotency: Reuses existing resources if names already exist.

RG_NAME=${RG_NAME:-lab9}
LOCATION=${LOCATION:-southeastasia}
STORAGE_NAME=${STORAGE_NAME:-lab9st$(openssl rand -hex 3)}
KV_NAME=${KV_NAME:-lab9kv$(openssl rand -hex 3)}
ACR_NAME=${ACR_NAME:-lab9acr$(openssl rand -hex 3)}
TFVARS_FILE=${TFVARS_FILE:-lab9-prereqs.auto.tfvars}

log() { echo "[lab9-prereqs] $*"; }

log "Ensuring resource group: $RG_NAME ($LOCATION)"
az group create -n "$RG_NAME" -l "$LOCATION" -o none

if az storage account show -n "$STORAGE_NAME" -g "$RG_NAME" >/dev/null 2>&1; then
  log "Storage account exists: $STORAGE_NAME"
else
  log "Creating storage account: $STORAGE_NAME"
  az storage account create -n "$STORAGE_NAME" -g "$RG_NAME" -l "$LOCATION" --sku Standard_LRS --kind StorageV2 -o none
fi
STORAGE_ID=$(az storage account show -n "$STORAGE_NAME" -g "$RG_NAME" --query id -o tsv)

if az keyvault show -n "$KV_NAME" -g "$RG_NAME" >/dev/null 2>&1; then
  log "Key Vault exists: $KV_NAME"
else
  log "Creating key vault: $KV_NAME"
  az keyvault create -n "$KV_NAME" -g "$RG_NAME" -l "$LOCATION" --enable-rbac-authorization true -o none || true
fi
KV_ID=$(az keyvault show -n "$KV_NAME" -g "$RG_NAME" --query id -o tsv)

if az acr show -n "$ACR_NAME" -g "$RG_NAME" >/dev/null 2>&1; then
  log "ACR exists: $ACR_NAME"
else
  log "Creating container registry: $ACR_NAME"
  az acr create -n "$ACR_NAME" -g "$RG_NAME" -l "$LOCATION" --sku Basic -o none
fi
ACR_ID=$(az acr show -n "$ACR_NAME" -g "$RG_NAME" --query id -o tsv)

log "Writing tfvars file: $TFVARS_FILE"
cat > "$TFVARS_FILE" <<EOF
storage_account_id = "$STORAGE_ID"
key_vault_id       = "$KV_ID"
acr_id             = "$ACR_ID"
EOF

log "Generated $TFVARS_FILE content:"; echo "---"; cat "$TFVARS_FILE"; echo "---"
log "Next: run 'terraform init && terraform plan' in this directory."
