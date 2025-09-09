# Lab 6 – Importing Existing Azure Resources into Terraform State

## Overview
Real environments contain pre-existing ("brownfield") resources. This lab shows two techniques to bring them under Terraform management without recreating:
* Terraform 1.5+ native `import {}` blocks (declarative imports)
* Legacy `terraform import` CLI commands (imperative)

You will:
1. Provision sample Azure resources OUTSIDE Terraform (script) – Storage Account + Container, VNet + Subnet, Public IP
2. Define matching Terraform resource blocks
3. Use import blocks to hydrate state
4. Validate zero-drift plan
5. Introduce & detect drift
6. Selectively manage only some resources (data source vs resource)
7. (Optional) Practice state surgery: `terraform state rm`, re-import, module addressing

## Why This Matters
Adopting Terraform incrementally avoids disruptive rebuilds. Proper import:
* Prevents accidental recreation of critical workloads
* Enables drift detection & policy enforcement
* Lets you phase migration (start with networking/storage before compute)

## Prerequisites
* Azure CLI logged in (`az account show` works)
* Terraform >= 1.5
* Bash shell
* Subscription-level permissions to read + create networking/storage

## Bootstrap Existing Resources
```bash
cd solutions/lab6
chmod +x prepare.sh
./prepare.sh
# Exports (copy from script output)
export TF_VAR_subscription_id=$(az account show --query id -o tsv)
```

## Review Terraform Configuration
Key files:
* `main.tf` – Desired resource definitions matching remote settings
* `import.tf` – Declarative import blocks (Terraform will perform imports before planning)
* `variables.tf` – Names/IDs (subscription variable feeds import block IDs)
* `outputs.tf` – Quick verification of imported IDs

We intentionally use a data source for the resource group to show selective adoption. You could switch to a managed `azurerm_resource_group` later.

## Perform Imports (Declarative)
```bash
terraform init
terraform plan
terraform apply -auto-approve
```
On first run Terraform will import each remote object referenced in `import.tf`. Expect output lines like:
```
azurerm_public_ip.imported: Importing...
...
azurerm_storage_container.imported: Import complete...
```
Apply should show `Apply complete! Resources: 5 imported, 0 added, 0 changed, 0 destroyed.` if definitions exactly match.

## Legacy Imperative Import (Optional)
If you comment out the blocks in `import.tf`, you can practice manual imports:
```bash
terraform state list            # empty (except provider)
terraform import azurerm_storage_account.imported \
  /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<name>
terraform import azurerm_storage_container.imported \
  https://<acct>.blob.core.windows.net/<container>
# Repeat for vnet, subnet, public IP
terraform plan
```

## Introducing Drift
Change a property directly in Azure (e.g. set a storage account tag):
```bash
az tag create --resource-id $(terraform output -raw storage_account_id) --tags Owner=DriftDemo || \
az tag update --resource-id $(terraform output -raw storage_account_id) --operation Merge --tags Owner=DriftDemo
```
Then:
```bash
terraform plan
```
If tag not represented locally, plan will propose removing it (depending on provider defaults / ignore_changes). Add the tag block locally to reconcile.

## Selective Adoption
We did not import the resource group. Reasons:
* Another team may manage it
* Avoid unintentional deletion if Terraform config removed
To adopt later, replace the data source with:
```hcl
resource "azurerm_resource_group" "existing" { name = var.resource_group_name location = var.location }
```
Remove the `data` block, run `terraform import azurerm_resource_group.existing /subscriptions/<sub>/resourceGroups/<name>` (or add import block), then plan.

## State Hygiene Exercises (Optional)
1. Remove one resource from state (not Azure):
```bash
terraform state rm azurerm_public_ip.imported
```
2. Run `terraform plan` – now Terraform thinks it must CREATE the Public IP.
3. Re-import it (or uncomment import block) to restore alignment.

### Module Address Import Example
If these lived in a module called `module.network`, you'd use:
```
import {
  to = module.network.azurerm_virtual_network.this
  id = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<name>"
}
```

## Troubleshooting
| Symptom | Cause | Fix |
|--------|-------|-----|
| Plan wants to recreate resource after import | Config mismatch | Align arguments with Azure settings; check SKU, address space, replication type |
| Import ID rejected | Wrong format | Copy exact patterns from script output |
| Extra attributes appear in plan | Provider defaults not declared | Either accept (no-op) or pin desired attributes explicitly |
| Drift not detected for a field | Field not managed / read-only | Confirm attribute is configurable; some are computed |

## Cleanup (Optional)
```bash
az group delete -n $(terraform output -raw azurerm_resource_group_name 2>/dev/null || echo lab6-rg) --yes --no-wait
```
(Or manually delete imported resources.)

## Key Learning Outcomes
* Use `import {}` blocks for reproducible, reviewable imports
* Build minimal accurate resource blocks before importing
* Detect and reconcile drift
* Migrate gradually (data sources → managed resources)
* Perform safe state surgery (remove + re-import)

## Next Ideas
* Import a Key Vault & secrets (pay attention to soft-delete + purge protection) 
* Move imported resources into modules (`terraform state mv`)
* Add CI to fail if drift detected (scheduled plan)