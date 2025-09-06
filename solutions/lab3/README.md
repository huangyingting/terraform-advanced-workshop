# Lab 3: Advanced Policy as Code & Remediation

## Overview
This lab demonstrates enterprise-grade Azure Policy governance using custom policy definitions, policy initiatives (policy sets), and automated remediation. You'll learn how to implement Policy as Code patterns with Terraform, create deployIfNotExists policies, and automate compliance remediation tasks.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Azure Subscription                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┤
│  │               Policy Framework                              │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │  Custom Policy Definitions                              │
│  │  │  ├── require-cost-center-tag (modify effect)            │
│  │  │  ├── require-disk-encryption (deny effect)              │
│  │  │  └── deploy-ama-linux-vms (deployIfNotExists)           │
│  │  └─────────────────────────────────────────────────────────┘
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │  Policy Initiative                                      │
│  │  │  ├── Enterprise Governance Initiative                   │
│  │  │  ├── Groups: 3 Custom Policies                          │
│  │  │  └── Parameters: Tag Name/Value, Workspace ID           │
│  │  └─────────────────────────────────────────────────────────┘
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │  Policy Assignment                                      │
│  │  │  ├── Scope: Subscription Level                          │
│  │  │  ├── Identity: System-Assigned Managed Identity         │
│  │  │  └── Role Assignments: Contributor, VM Contributor      │
│  │  └─────────────────────────────────────────────────────────┘
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │  Remediation Tasks                                      │
│  │  │  ├── Tag Remediation (azurerm_policy_remediation)       │
│  │  │  └── AMA Remediation (azapi_resource)                   │
│  │  └─────────────────────────────────────────────────────────┘
│  └─────────────────────────────────────────────────────────────┘
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┤
│  │               Supporting Infrastructure                     │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │  Resource Group: rg-policy-logs                         │
│  │  │  └── Log Analytics Workspace: law-policy-governance     │
│  │  └─────────────────────────────────────────────────────────┘
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │  Resource Group: rg-policy-testing                      │
│  │  │  ├── Virtual Network: vnet-policy-test                  │
│  │  │  ├── Subnet: subnet-vms (10.0.1.0/24)                  │
│  │  │  ├── Network Security Group: nsg-policy-test            │
│  │  │  ├── Public IP: pip-test-vm                             │
│  │  │  ├── Network Interface: nic-test-vm                     │
│  │  │  └── Linux VM: vm-policy-test (non-compliant initially) │
│  │  └─────────────────────────────────────────────────────────┘
│  └─────────────────────────────────────────────────────────────┘
│                                                                 │
│  Policy Flow:                                                   │
│  1. VM created without required tag → Modify policy adds tag   │
│  2. VM created without AMA → DeployIfNotExists installs agent  │
│  3. Remediation tasks automatically fix non-compliant resources │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required Permissions
- **Azure Subscription**: Owner or Policy Contributor role
- **Resource Groups**: Contributor role (to create and manage resources)
- **Policy Operations**: Policy Contributor role for policy definitions and assignments
- **Remediation**: Resource Policy Contributor role for remediation tasks

### Required Tools
- Azure CLI v2.50+ authenticated and configured
- Terraform v1.7+ installed
- SSH key pair for VM access
- Git for version control
- VS Code with Terraform extension (recommended)

### Azure Provider Registration
Ensure the following providers are registered:
```bash
# Register required providers
az provider register --namespace Microsoft.PolicyInsights
az provider register --namespace Microsoft.Authorization
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.OperationalInsights
```

## Directory Structure
```
lab3/
├── README.md                       # This file
├── providers.tf                    # Provider configurations
├── variables.tf                    # Input variables
├── main.tf                        # Main Terraform configuration
├── outputs.tf                     # Output definitions
└── policies/                      # Policy definition JSON files
    ├── require-tag.json           # Tag policy with modify effect
    ├── require-disk-encryption.json # Disk encryption policy with deny effect
    └── ensure-ama.json            # AMA deployment policy
```

## Step-by-Step Instructions

### Step 1: Environment Setup

1. **Navigate to the lab directory:**
   ```bash
   cd solutions/lab3
   ```

2. **Set required environment variables:**
   ```bash
   # Set default location
   export TF_VAR_location="southeastasia"
   
   # Set subscription ID (if not already set)
   export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
   ```

3. **Verify Azure CLI authentication:**
   ```bash
   # Verify you're logged in with correct subscription
   az account show
   
   # Check your permissions
   az role assignment list --assignee $(az account show --query user.name -o tsv) --include-inherited
   ```

### Step 2: Review Configuration Files

1. **Examine the policy definitions:**
   ```bash
   # Review the tag policy with modify effect
   cat policies/require-tag.json
   
   # Review the disk encryption policy with deny effect
   cat policies/require-disk-encryption.json
   
   # Review the AMA deployment policy
   cat policies/ensure-ama.json
   ```

2. **Review the Terraform configuration:**
   ```bash
   # Main configuration with policy definitions and assignments
   cat main.tf
   
   # Variables for customization
   cat variables.tf
   
   # Expected outputs
   cat outputs.tf
   ```

### Step 3: Customize Variables (Optional)

Create a `terraform.tfvars` file to customize the deployment:

```bash
cat > terraform.tfvars << EOF
location                   = "southeastasia"
resource_group_name       = "rg-policy-testing"
tag_name                  = "cost-center"
tag_value                 = "finance"
vm_admin_username         = "azureuser"
ssh_public_key_path       = "~/.ssh/id_rsa.pub"
EOF
```

### Step 4: Deploy the Policy Framework

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Review the deployment plan:**
   ```bash
   terraform plan
   ```

   The plan should show:
   - 3 custom policy definitions
   - 1 policy initiative (policy set definition)
   - 1 subscription-level policy assignment
   - 2 role assignments for policy remediation
   - Supporting infrastructure (Log Analytics, test resources)
   - 2 remediation tasks

3. **Deploy the infrastructure:**
   ```bash
   terraform apply
   ```

   **Note**: The deployment may take 5-10 minutes as it includes:
   - Policy propagation across Azure
   - VM deployment
   - Remediation task execution

### Step 5: Verify Policy Compliance

1. **Check policy assignment status:**
   ```bash
   # Get the policy assignment ID from Terraform output
   terraform output policy_assignment_id
   
   # Check compliance state (may take 15-30 minutes to fully populate)
   az policy state list --filter "PolicyAssignmentId eq '$(terraform output -raw policy_assignment_id)'"
   ```

2. **Monitor remediation tasks:**
   ```bash
   # List all remediation tasks
   az policy remediation list
   
   # Check specific remediation task status
   az policy remediation show --name "remediate-missing-tags"
   ```

3. **Verify test VM compliance:**
   ```bash
   # Check if the required tag was added to the test VM
   az vm show --name vm-policy-test --resource-group $(terraform output -raw test_resource_group_name) --query tags
   
   # Check if AMA extension was installed
   az vm extension list --vm-name vm-policy-test --resource-group $(terraform output -raw test_resource_group_name) --query "[?name=='AzureMonitorLinuxAgent']"
   ```

### Step 6: Test Policy Enforcement

1. **Attempt to create a non-compliant resource:**
   ```bash
   # Try to create a VM without the required tag (should be modified by policy)
   az vm create \
     --resource-group $(terraform output -raw test_resource_group_name) \
     --name vm-test-compliance \
     --image Ubuntu2204 \
     --admin-username azureuser \
     --generate-ssh-keys \
     --size Standard_B1s \
     --tags Environment=Test
   ```

2. **Verify policy effects:**
   ```bash
   # Check if the tag was automatically added
   az vm show --name vm-test-compliance --resource-group $(terraform output -raw test_resource_group_name) --query tags
   ```

### Step 7: View Policy Compliance in Azure Portal

1. **Open Azure Portal and navigate to Policy:**
   ```bash
   # Get the compliance URL from Terraform output
   terraform output policy_compliance_url
   ```

2. **Review compliance dashboard:**
   - Navigate to Azure Policy in the portal
   - View the "Enterprise Governance Initiative" assignment
   - Check compliance state for each policy in the initiative
   - Review remediation task history

### Step 8: Test Advanced Scenarios (Optional)

1. **Create additional test resources:**
   ```bash
   # Create a storage account without the required tag
   az storage account create \
     --name "testpolicy$(date +%s)" \
     --resource-group $(terraform output -raw test_resource_group_name) \
     --location $(terraform output -raw location) \
     --sku Standard_LRS
   ```

2. **Trigger manual remediation:**
   ```bash
   # Create a new remediation task for recent resources
   az policy remediation create \
     --name "manual-tag-remediation" \
     --policy-assignment $(terraform output -raw policy_assignment_id) \
     --definition-reference-id "RequireTag"
   ```

## Validation Checklist

### ✅ Policy Framework Deployment
- [ ] 3 custom policy definitions created successfully
- [ ] Policy initiative created with all 3 policies
- [ ] Subscription-level policy assignment configured
- [ ] System-assigned managed identity created and assigned roles
- [ ] Remediation tasks created and executed

### ✅ Infrastructure Compliance
- [ ] Test VM created initially without required tag
- [ ] Required tag automatically added through policy remediation
- [ ] Azure Monitor Agent installed via deployIfNotExists policy
- [ ] All resources show compliant status in Azure Policy dashboard

### ✅ Policy Effectiveness
- [ ] New resources automatically get required tags through modify policy
- [ ] VMs without disk encryption are denied (if disk encryption policy is enforced)
- [ ] Linux VMs automatically get AMA extension installed
- [ ] Remediation tasks successfully fix non-compliant existing resources

## Troubleshooting

### Common Issues

1. **Policy Assignment Takes Time to Propagate**
   ```bash
   # Policy effects may take 15-30 minutes to fully propagate
   # Check policy evaluation status
   az policy state list --filter "PolicyAssignmentId eq '$(terraform output -raw policy_assignment_id)'"
   ```

2. **Remediation Tasks Not Running**
   ```bash
   # Verify managed identity has correct permissions
   az role assignment list --assignee $(az policy assignment show --name enterprise-governance-assignment --scope /subscriptions/$(az account show --query id -o tsv) --query identity.principalId -o tsv)
   
   # Manually trigger remediation
   az policy remediation create --name "manual-remediation" --policy-assignment $(terraform output -raw policy_assignment_id)
   ```

3. **SSH Key Issues for Test VM**
   ```bash
   # Generate SSH key if it doesn't exist
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
   
   # Update terraform.tfvars with correct path
   echo 'ssh_public_key_path = "~/.ssh/id_rsa.pub"' >> terraform.tfvars
   ```

4. **Permission Errors**
   ```bash
   # Verify you have Policy Contributor role
   az role assignment list --assignee $(az account show --query user.name -o tsv) --query "[?roleDefinitionName=='Policy Contributor']"
   
   # If missing, request from subscription owner:
   # az role assignment create --assignee $(az account show --query user.name -o tsv) --role "Policy Contributor" --scope /subscriptions/$(az account show --query id -o tsv)
   ```

## Cleanup

1. **Remove test resources first:**
   ```bash
   # Delete any manually created test resources
   az vm delete --name vm-test-compliance --resource-group $(terraform output -raw test_resource_group_name) --yes
   ```

2. **Destroy Terraform-managed resources:**
   ```bash
   terraform destroy
   ```

   **Note**: Policy assignments and definitions may take additional time to fully remove from Azure.

3. **Verify cleanup:**
   ```bash
   # Check that policy assignment is removed
   az policy assignment list --query "[?displayName=='Enterprise Governance Policy Assignment']"
   
   # Check that custom policies are removed
   az policy definition list --query "[?policyType=='Custom' && displayName contains 'Enterprise']"
   ```

## Success Criteria

### ✅ Policy as Code Implementation
- Policy definitions authored as JSON files and deployed via Terraform
- Policy initiative created to group related policies
- Parameterized policies for flexible deployment

### ✅ Advanced Policy Effects Demonstrated
- **Modify Effect**: Automatic tag addition to non-compliant resources
- **Deny Effect**: Prevention of non-compliant resource creation
- **DeployIfNotExists Effect**: Automatic deployment of required extensions

### ✅ Automated Remediation
- Remediation tasks created and executed via Terraform
- Non-compliant existing resources automatically fixed
- Manual remediation capability demonstrated

### ✅ Enterprise Governance
- Subscription-level policy enforcement
- Role-based access control for policy operations
- Compliance monitoring and reporting through Azure Portal

## Learning Outcomes

After completing this lab, you will have hands-on experience with:

1. **Policy as Code Patterns**: Using Terraform to manage Azure Policy lifecycle
2. **Advanced Policy Effects**: Implementing modify, deny, and deployIfNotExists effects
3. **Policy Initiatives**: Grouping related policies for coherent governance
4. **Automated Remediation**: Using Terraform to orchestrate compliance remediation
5. **Enterprise Governance**: Applying policies at scale with proper RBAC

## Next Steps

- **Lab 4**: Implement CI/CD pipelines for policy deployments
- **Advanced Topics**: Explore policy exemptions, regulatory compliance initiatives
- **Integration**: Combine with Azure Landing Zones for comprehensive governance
