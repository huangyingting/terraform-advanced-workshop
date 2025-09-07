# Lab 3: Advanced Policy as Code & Remediation

## Overview
This lab implements Azure Policy as Code using Terraform to provision:
* Three custom policy definitions (modify, deny, deployIfNotExists)
* A custom policy initiative (policy set definition)
* A resource-group scoped policy assignment (SystemAssigned identity)
* Role assignments granting least privileges for remediation at RG scope
* Two remediation tasks (tag + AMA) implemented with `azapi_resource`
* A deliberately non‑compliant Linux VM to trigger modify and deployIfNotExists, and highlight a deny scenario

You also see optional dynamic creation of a Log Analytics workspace, how to scope policy narrowly (RG instead of subscription), and how to use AzAPI where the AzureRM provider lacks first‑class remediation support.

## Prerequisites
- Azure subscription with Policy Contributor or Owner role
- Azure CLI v2.50+ logged in (az account show succeeds)
- Terraform v1.7+ installed
- jq installed (used by prepare script)
- Strong admin password you will supply (or script will generate one) meeting Azure complexity (≥12 chars, mix of upper/lower/digit/symbol)
- Registered resource providers:
  - Microsoft.PolicyInsights
  - Microsoft.Authorization
  - Microsoft.Compute
  - Microsoft.Network
  - Microsoft.OperationalInsights
  - Microsoft.Insights
  - Microsoft.ManagedIdentity

(Optional) Run helper script to validate and bootstrap:
```bash
cd solutions/lab3
chmod +x prepare.sh
./prepare.sh
```

## Step-by-Step Instructions

### 1. Review & (Optionally) Customize Variables
Default values live in `variables.tf`. To override, create `terraform.tfvars`:
```hcl
location             = "southeastasia"
resource_group_name  = "lab3-rg"
tag_name             = "cost-center"
tag_value            = "lab3"
vm_admin_username    = "azureuser"
vm_admin_password    = "ChangeM3!" # supply a strong password or export TF_VAR_vm_admin_password
# log_analytics_workspace_id = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<name>" # (optional reuse)
```
If `log_analytics_workspace_id` is not supplied, the configuration creates `lab3-policy-logs-rg` and `lab3-law-policy-governance` automatically.

### 2. Initialize Terraform
```bash
terraform init
```
Downloads AzureRM (~>3.100) and AzAPI (~>1.9) providers.

### 3. Plan Deployment
```bash
terraform plan
```
Confirm the plan shows (approximate):
Expected resources:
* 3 x `azurerm_policy_definition`
* 1 x `azurerm_policy_set_definition`
* 1 x `azurerm_resource_group_policy_assignment` (SystemAssigned identity)
* 2 x `azurerm_role_assignment` (Contributor + VM Contributor) at RG scope
* 2 x `azapi_resource` (remediation objects: tag + AMA) – optional if enabled
* Optional Log Analytics RG + workspace (if you didn’t supply one)
* Test RG + networking + Linux VM

### 4. Apply Deployment
```bash
terraform apply -auto-approve
```
Notes:
- Policy assignment + initial compliance evaluation can take several minutes.
- Remediation tasks run after evaluation; status may remain "InProgress" briefly.
- The modify effect will add the required tag to resources missing it inside the RG.

### 5. Verify Core Artifacts
```bash
terraform output
RG=$(terraform output -raw test_resource_group_name)
az policy assignment list --resource-group "$RG" -o table | grep enterprise-governance-assignment || true
az policy definition list --query "[?policyType=='Custom' && (contains(name,'require-') || contains(name,'deploy-ama'))]" -o table
```
Check managed identity role assignments:
```bash
ASSIGN_ID=$(terraform output -raw policy_assignment_id)
PRINCIPAL_ID=$(az policy assignment show --name enterprise-governance-assignment --resource-group "$RG" --query identity.principalId -o tsv)
az role assignment list --assignee "$PRINCIPAL_ID" --scope $(az group show -n "$RG" --query id -o tsv) -o table
```

### 6. Inspect Remediation
```bash
az policy remediation list --resource-group "$RG" -o table
az policy state list --resource-group "$RG" --top 50 -o table
```
Check VM tag, AMA extension, and OS disk encryption status:
```bash
RG=$(terraform output -raw test_resource_group_name)
az vm show --name vm-policy-test --resource-group $RG --query tags
az vm extension list --vm-name vm-policy-test --resource-group $RG --query "[?name=='AzureMonitorLinuxAgent']"
OSDISK_ID=$(az vm show --name vm-policy-test --resource-group $RG --query "storageProfile.osDisk.managedDisk.id" -o tsv)
az disk show --ids $OSDISK_ID --query "encryption.type"
# (Optional) Check encryption at host setting
az vm show --name vm-policy-test --resource-group $RG --query "securityProfile.encryptionAtHost"
```

### 7. Test Policy Effects
Attempt non-compliant resource (tag auto-added by modify effect):
```bash
RG=$(terraform output -raw test_resource_group_name)
az network nsg create -g $RG -n nsg-extra-test --tags Purpose=AdHoc
az vm create \
  --resource-group $RG \
  --name vm-extra-test \
  --image Ubuntu2204 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --size Standard_B1s \
  --tags Purpose=AdHoc
```

As you attempt to create a VM without the required disk encryption, the disk encryption policy's deny effect will block the deployment (Azure CLI will return a Policy violation error and the VM will not be created).

### 8. (Optional) Trigger Manual Remediation
```bash
ASSIGN_ID=$(terraform output -raw policy_assignment_id)
RG=$(terraform output -raw test_resource_group_name)
az policy remediation create \
  --name manual-tag-remediation \
  --policy-assignment $ASSIGN_ID \
  --resource-group $RG \
  --definition-reference-id RequireTag
```

### 9. View Compliance in Portal
Open the Policy blade:
```bash
echo "https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyComplianceBlade"
```
Locate initiative “Enterprise Governance Initiative”.

### 10. Destroy (Cleanup)
Destroy in one step:
```bash
terraform destroy -auto-approve
```
Verify removal:
```bash
RG=$(terraform output -raw test_resource_group_name 2>/dev/null || echo none)
az policy assignment list --resource-group $RG --query "[?name=='enterprise-governance-assignment']" || true
az policy definition list --query "[?policyType=='Custom' && contains(displayName,'Governance')]"
```

If the resource group is already gone, the RG-scoped policy assignment is implicitly removed.

## Key Learning Outcomes
* Policy as Code lifecycle with Terraform (definitions → initiative → scoped assignment → remediation)
* Narrow scoping (RG vs subscription) to reduce blast radius during experimentation
* Implementing modify, deny & deployIfNotExists effects cohesively
* Using System Assigned Managed Identity with least-privilege RG role assignments
* Leveraging AzAPI for remediation artifacts not yet first‑class in AzureRM
* Parameterizing tag + workspace inputs for reusable governance patterns
* Validating compliance & remediation via CLI and Portal
* Ordering infrastructure before policy to observe remediation behavior

## Questions
1. How would you extend this initiative to include regulatory (e.g., CIS, NIST) built‑in policies without overwhelming remediation capacity?
2. What strategy ensures safe rollout of deny policies in production environments (staging, exemptions, what‑if)?
3. How would you adapt this pattern for multiple subscriptions at management group scope while maintaining least privilege?
4. What telemetry (logs, metrics) would you capture to measure governance effectiveness over time?
5. How could you decouple remediation cadence from policy assignment to reduce blast radius?
6. When would you choose deployIfNotExists vs remediation, and how do you govern drift afterwards?

## Additional Resources
- Azure Policy Concepts: https://learn.microsoft.com/azure/governance/policy/concepts
- Terraform AzureRM Provider Policy Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_definition
- AzAPI Provider: https://registry.terraform.io/providers/Azure/azapi/latest
- Policy Remediation Guidance: https://learn.microsoft.com/azure/governance/policy/how-to/remediate-resources
- Effects Reference (deny/modify/deployIfNotExists): https://learn.microsoft.com/azure/governance/policy/concepts/effects
- Azure Monitor Agent Overview: https://learn.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-overview
