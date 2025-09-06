# Lab 2: Landing Zone Foundation with Azure Verified Modules

## Overview
This lab demonstrates how to deploy a production-ready Azure Landing Zone foundation using Azure Verified Modules (AVM) with multi-subscription architecture. You'll learn advanced Terraform patterns including provider aliases, module composition, and enterprise-scale governance deployment.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Tenant                             │
│  ┌─────────────────────────────────────────────────────────┤
│  │           Management Group Hierarchy                    │
│  │  ┌─────────────────────────────────────────────────────┤
│  │  │  alz (Root Management Group)                        │
│  │  │  ├── alz-platform                                   │
│  │  │  │   ├── alz-management                             │
│  │  │  │   └── alz-connectivity                           │
│  │  │  └── alz-landing-zones                              │
│  │  │      ├── alz-online                                 │
│  │  │      └── alz-corp                                   │
│  └──┴──┴──────────────────────────────────────────────────┘
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────────────┐ │
│  │  Management Sub     │    │   Connectivity Sub          │ │
│  │  ┌─────────────────┐│    │  ┌─────────────────────────┐│ │
│  │  │ Log Analytics   ││    │  │  Hub Virtual Network   ││ │
│  │  │ Workspace       ││    │  │  ┌─────────────────────┐││ │
│  │  │                 ││    │  │  │  Azure Firewall     │││ │
│  │  │ Data Collection ││    │  │  │                     │││ │
│  │  │ Rules          ││    │  │  │  Public IP          │││ │
│  │  │                 ││    │  │  └─────────────────────┘││ │
│  │  │ User-Assigned   ││    │  │                         ││ │
│  │  │ Managed Identity││    │  │  Subnets:               ││ │
│  │  │                 ││    │  │  - AzureFirewallSubnet  ││ │
│  │  │ Monitoring      ││    │  │  - User Subnets        ││ │
│  │  │ Solutions       ││    │  │                         ││ │
│  │  └─────────────────┘│    │  └─────────────────────────┘│ │
│  └─────────────────────┘    └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required Permissions
- **Tenant Root Management Group**: Owner or User Access Administrator role
- **Management Subscription**: Contributor or Owner role  
- **Connectivity Subscription**: Contributor or Owner role

### Required Tools
- Azure CLI v2.50+ authenticated and configured
- Terraform v1.7+ installed
- Git for version control
- VS Code with Terraform extension (recommended)

### Azure Provider Registration
Ensure the following providers are registered in both subscriptions:
```bash
# Register required providers
az provider register --namespace Microsoft.PolicyInsights
az provider register --namespace Microsoft.Authorization
az provider register --namespace Microsoft.Management
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ManagedIdentity
```

## Step-by-Step Instructions

### Step 1: Environment Setup

1. **Set subscription IDs as environment variables:**
   ```bash
   # Export your Management subscription ID
   export MGMT_SUB_ID="your-management-subscription-id"
   
   # Export your Connectivity subscription ID  
   export CONN_SUB_ID="your-connectivity-subscription-id"
   
   # Set default location (adjust as needed)
   export TF_VAR_location="southeastasia"
   ```

2. **Verify Azure CLI authentication:**
   ```bash
   # Verify you're logged in
   az account show
   
   # List available subscriptions
   az account list --output table
   
   # Verify tenant permissions
   az role assignment list --scope "/" --include-inherited
   ```

3. **Navigate to the lab directory:**
   ```bash
   cd solutions/lab2
   ```

### Step 2: Review the Configuration Files

The lab includes the following pre-configured files:

#### `providers.tf`
```hcl
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    alz = {
      source  = "azure/alz"
      version = "~> 0.19"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.management_subscription_id
}

provider "azurerm" {
  alias           = "connectivity"
  features {}
  subscription_id = var.connectivity_subscription_id
}

provider "alz" {
  library_references = [
    {
      path = "platform/alz"
      ref  = "2025.02.0"
    }
  ]
}

variable "management_subscription_id" { type = string }
variable "connectivity_subscription_id" { type = string }
variable "location" {
  type    = string
  default = "southeastasia"
}
```

#### `main.tf`
```hcl
# Azure Landing Zone pattern modules with correct parameters

# Data source to get current tenant information
data "azurerm_client_config" "current" {}

module "alz_core" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "~> 0.13"

  # Required parameters
  architecture_name  = "alz"
  location           = var.location  
  parent_resource_id = data.azurerm_client_config.current.tenant_id
}

module "management" {
  source  = "Azure/avm-ptn-alz-management/azurerm"
  version = "~> 0.9"

  providers = { azurerm = azurerm }
  
  # Required parameters
  location                     = var.location
  resource_group_name          = "rg-alz-management"
  automation_account_name      = "aa-alz-management" 
  log_analytics_workspace_name = "law-alz-management"
}

module "hub_network" {
  source  = "Azure/avm-ptn-hubnetworking/azurerm"
  version = "~> 0.12"

  providers = { azurerm = azurerm.connectivity }
  
  # Required parameter
  hub_virtual_networks = {
    primary = {
      name                = "vnet-hub-primary"
      address_space       = ["10.0.0.0/16"]
      location           = var.location
      resource_group_name = "rg-hub-networking"
    }
  }
}
```

### Step 3: Initialize Terraform

1. **Initialize the Terraform working directory:**
   ```bash
   terraform init
   ```
   
   This command will:
   - Download the required providers (azurerm, alz, azapi, etc.)
   - Download the Azure Verified Modules
   - Initialize the backend (local for this lab)

2. **Verify initialization was successful:**
   ```bash
   # Should show no errors
   echo $?
   ```

### Step 4: Review the Deployment Plan

1. **Generate and review the deployment plan:**
   ```bash
   terraform plan \
     -var="management_subscription_id=$MGMT_SUB_ID" \
     -var="connectivity_subscription_id=$CONN_SUB_ID"
   ```

2. **Expected resources to be created:**
   - **Management Groups**: Root ALZ hierarchy with policy assignments
   - **Policy Definitions**: Custom and built-in policies for governance
   - **Role Definitions**: Custom roles for landing zone operations
   - **Log Analytics Workspace**: Centralized logging (management subscription)
   - **Data Collection Rules**: For Azure Monitor Agent
   - **Hub Virtual Network**: Core networking infrastructure (connectivity subscription)
   - **Resource Groups**: Container resources across subscriptions

   The plan should show approximately 400+ resources to be created.

### Step 5: Deploy the Infrastructure

1. **Apply the Terraform configuration:**
   ```bash
   terraform apply \
     -var="management_subscription_id=$MGMT_SUB_ID" \
     -var="connectivity_subscription_id=$CONN_SUB_ID"
   ```

2. **Confirm the deployment when prompted:**
   ```
   Do you want to perform these actions?
   Terraform will perform the actions described above.
   Only 'yes' will be accepted to approve.

   Enter a value: yes
   ```

3. **Monitor the deployment progress:**
   - The deployment typically takes 15-25 minutes
   - Management groups and policies are created first
   - Followed by management resources
   - Finally networking resources

### Step 6: Verify the Deployment

#### Verify Management Groups
1. **Check management groups in Azure Portal:**
   ```bash
   # Open Azure Portal
   az portal browse --path /providers/Microsoft.Management/managementGroups
   ```

2. **Expected management group structure:**
   ```
   Tenant Root Group
   └── alz (Azure Landing Zone)
       ├── alz-platform
       │   ├── alz-management
       │   └── alz-connectivity
       └── alz-landing-zones
           ├── alz-online
           └── alz-corp
   ```

#### Verify Management Resources
1. **Check Log Analytics workspace:**
   ```bash
   az monitor log-analytics workspace show \
     --resource-group rg-alz-management \
     --workspace-name law-alz-management \
     --subscription $MGMT_SUB_ID
   ```

2. **Verify data collection rules:**
   ```bash
   az monitor data-collection rule list \
     --resource-group rg-alz-management \
     --subscription $MGMT_SUB_ID
   ```

#### Verify Hub Networking
1. **Check hub virtual network:**
   ```bash
   az network vnet show \
     --name vnet-hub-primary \
     --resource-group rg-hub-networking \
     --subscription $CONN_SUB_ID
   ```

2. **List network resources:**
   ```bash
   az resource list \
     --resource-group rg-hub-networking \
     --subscription $CONN_SUB_ID \
     --output table
   ```

### Step 7: Explore Policy Assignments

1. **List policy assignments at management group scope:**
   ```bash
   az policy assignment list \
     --scope "/providers/Microsoft.Management/managementGroups/alz" \
     --output table
   ```

2. **Check policy compliance:**
   ```bash
   az policy state list \
     --management-group alz \
     --output table
   ```

## Key Terraform Patterns Demonstrated

### 1. Provider Aliases for Multi-Subscription Deployment
```hcl
provider "azurerm" {
  # Default provider for management subscription
  subscription_id = var.management_subscription_id
}

provider "azurerm" {
  alias           = "connectivity"
  subscription_id = var.connectivity_subscription_id
}
```

### 2. Module Provider Assignment
```hcl
module "hub_network" {
  source = "Azure/avm-ptn-hubnetworking/azurerm"
  
  # Explicitly assign the connectivity provider
  providers = { azurerm = azurerm.connectivity }
  # ... other configuration
}
```

### 3. Data Source for Tenant Information
```hcl
data "azurerm_client_config" "current" {}

# Use in module configuration
parent_resource_id = data.azurerm_client_config.current.tenant_id
```

### 4. Azure Verified Modules Pattern
```hcl
module "alz_core" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "~> 0.13"  # Use semantic versioning constraints
  
  # Required parameters only
  architecture_name  = "alz"
  location           = var.location
  parent_resource_id = data.azurerm_client_config.current.tenant_id
}
```

## Troubleshooting

### Common Issues and Solutions

#### Permission Issues
**Error**: `Insufficient privileges to complete the operation`
```bash
# Verify tenant-level permissions
az role assignment list --scope "/" --assignee $(az account show --query user.name -o tsv)

# If missing, request Owner or User Access Administrator at tenant root
```

#### Provider Registration
**Error**: `The subscription is not registered to use namespace 'Microsoft.PolicyInsights'`
```bash
# Register the required provider
az provider register --namespace Microsoft.PolicyInsights
az provider show --namespace Microsoft.PolicyInsights --query registrationState
```

#### Terraform State Issues
**Error**: `Resource already exists`
```bash
# If partial deployment failed, check state
terraform state list

# Import existing resources if needed
terraform import <resource_type>.<resource_name> <azure_resource_id>
```

#### Module Version Conflicts
**Error**: Module version constraints not met
```bash
# Clear module cache and re-initialize
rm -rf .terraform/modules
terraform init -upgrade
```

## Clean Up

When you're ready to clean up the resources:

1. **Destroy the infrastructure:**
   ```bash
   terraform destroy \
     -var="management_subscription_id=$MGMT_SUB_ID" \
     -var="connectivity_subscription_id=$CONN_SUB_ID"
   ```

2. **Confirm destruction:**
   ```
   Do you really want to destroy all resources?
   Terraform will destroy all your managed infrastructure, as shown above.
   There is no undo. Only 'yes' will be accepted to confirm.

   Enter a value: yes
   ```

⚠️ **Note**: Management groups may take some time to fully delete due to Azure's eventual consistency model.

## Next Steps

After completing this lab, you'll have:
- A fully functional Azure Landing Zone foundation
- Experience with multi-subscription Terraform deployments  
- Understanding of Azure Verified Modules patterns
- A foundation for deploying workloads in subsequent labs

Consider exploring:
- Custom policy development for your organization
- Additional hub networking features (VPN Gateway, ExpressRoute)
- Workload deployment in the landing zone subscriptions
- Integration with Azure DevOps or GitHub Actions for CI/CD

## Additional Resources

- [Azure Landing Zones Documentation](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [Cloud Adoption Framework](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/)
- [Azure Policy Documentation](https://docs.microsoft.com/en-us/azure/governance/policy/)
