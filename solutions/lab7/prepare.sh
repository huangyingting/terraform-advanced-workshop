#!/usr/bin/env bash
set -euo pipefail

# Lab7 helper: validate tooling and print instructions for Terraform Cloud setup.
# Does NOT create Azure resources (TFC run will). Optionally can fetch SP details.

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){ echo -e "${RED}[ERR]${NC} $*"; }

log "Checking prerequisites"
for cmd in terraform az gh; do
  if ! command -v "$cmd" >/dev/null 2>&1; then err "Missing required command: $cmd"; exit 1; fi
done
ok "CLI tools present"

if ! az account show >/dev/null 2>&1; then err "Run 'az login' first"; exit 1; fi
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
ok "Azure context: subscription=$SUBSCRIPTION_ID tenant=$TENANT_ID"

if [[ -z "${APP_NAME:-}" ]]; then
  APP_NAME="github-terraform-cicd"
  warn "APP_NAME not set, using default: ${APP_NAME}"
else
  ok "Using APP_NAME=${APP_NAME}"
fi

# Try to locate existing Azure AD application by display name (first match)
APP_ID=$(az ad app list --display-name "${APP_NAME}" --query '[0].appId' -o tsv 2>/dev/null || true)
if [[ -n "$APP_ID" && "$APP_ID" != "null" ]]; then
  export APP_ID
  ok "Resolved Azure AD application appId=${APP_ID} for APP_NAME=${APP_NAME}"
else
  warn "No existing Azure AD application found with display name '${APP_NAME}'. If needed, create one and rerun."
fi

cat <<EOF

Next steps:
1. Create / select Terraform Cloud organization.
2. Create workspace (VCS) pointing to repo directory solutions/lab7.
3. Set Env Vars in TFC (category=Env):
   - ARM_CLIENT_ID=$APP_ID
   - ARM_TENANT_ID=$TENANT_ID
   - ARM_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
4. (If using client secret) add ARM_CLIENT_SECRET (sensitive) – prefer federated identity when available.
5. Add Terraform vars as desired (location, resource_group_name, storage_account_suffix).
6. Update versions.tf cloud block placeholders OR remove block and set workspace backend manually.
7. Commit change to trigger plan; inspect run in TFC UI.

EOF
