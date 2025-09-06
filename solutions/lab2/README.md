# Lab 2: Landing Zone Foundation with Azure Verified Modules

## Overview

This lab demonstrates how to deploy a production-ready Azure Landing Zone foundation using Azure Verified Modules (AVM) with multi-subscription architecture. You'll learn advanced Terraform patterns including provider aliases for cross-subscription deployments, module composition techniques, and enterprise-scale governance implementation. The lab showcases how to use the ALZ (Azure Landing Zone) provider alongside Azure Verified Modules to create a complete landing zone foundation with management groups, policies, hub networking, and centralized logging across multiple Azure subscriptions.

## Prerequisites

### Required Permissions
- **Tenant Root Management Group**: Owner or User Access Administrator role
- **Management Subscription**: Contributor or Owner role  
- **Connectivity Subscription**: Contributor or Owner role
- **Azure AD**: Ability to create and manage service principals (if using automated deployments)

### Required Tools
- Azure CLI v2.50+ authenticated and configured
- Terraform v1.7+ installed
- Git for version control
- VS Code with Terraform extension (recommended)
- Two separate Azure subscriptions (management and connectivity)

### Environment Setup
```bash
# Verify Azure CLI authentication
az account show

# List available subscriptions
az account list --output table

# Set subscription IDs as environment variables
export MGMT_SUB_ID="your-management-subscription-id"
export CONN_SUB_ID="your-connectivity-subscription-id"
export TF_VAR_location="southeastasia"
```

### Azure Provider Registration
Ensure the following providers are registered in both subscriptions:
```bash
az provider register --namespace Microsoft.PolicyInsights
az provider register --namespace Microsoft.Authorization
az provider register --namespace Microsoft.Management
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ManagedIdentity
```

## Step-by-Step Instructions

### Step 1: Review the Configuration

1. **Navigate to the lab directory:**
   ```bash
   cd solutions/lab2
   ```

2. **Examine the provider configuration:**
   ```bash
   cat providers.tf
   ```
   
   Notice the multi-provider setup:
   - Default `azurerm` provider for management subscription
   - Aliased `azurerm.connectivity` provider for networking subscription
   - `alz` provider for Azure Landing Zone library references

3. **Review the main configuration:**
   ```bash
   cat main.tf
   ```
   
   Observe the three key modules:
   - `alz_core`: Creates management group hierarchy and policies
   - `management`: Deploys centralized logging and monitoring
   - `hub_network`: Creates hub networking infrastructure

### Step 2: Initialize Terraform

1. **Initialize the working directory:**
   ```bash
   terraform init
   ```
   
   This downloads:
   - Azure Verified Modules from the Terraform Registry
   - ALZ provider and its library references
   - Required provider plugins

2. **Verify initialization:**
   ```bash
   terraform providers
   ```

### Step 3: Plan the Deployment

1. **Generate deployment plan:**
   ```bash
   terraform plan \
     -var="management_subscription_id=$MGMT_SUB_ID" \
     -var="connectivity_subscription_id=$CONN_SUB_ID"
   ```

2. **Review the planned resources:**
   - **Management Groups**: ALZ hierarchy (platform, landing zones, corp, online)
   - **Policy Definitions**: Governance policies for security and compliance
   - **Role Definitions**: Custom roles for landing zone operations
   - **Log Analytics**: Centralized monitoring workspace
   - **Hub Network**: Core networking with subnets and NSGs
   - **Resource Groups**: Organizational containers

   Expected: ~400+ resources to be created

### Step 4: Deploy the Infrastructure

1. **Apply the configuration:**
   ```bash
   terraform apply \
     -var="management_subscription_id=$MGMT_SUB_ID" \
     -var="connectivity_subscription_id=$CONN_SUB_ID"
   ```

2. **Confirm deployment:**
   ```
   Enter a value: yes
   ```

3. **Monitor progress:**
   - Deployment typically takes 15-25 minutes
   - Management groups created first
   - Policies and roles follow
   - Management resources deployed
   - Networking infrastructure last

### Step 5: Verify the Deployment

1. **Check management group hierarchy:**
   ```bash
   az account management-group list --output table
   ```

2. **Verify Log Analytics workspace:**
   ```bash
   az monitor log-analytics workspace show \
     --resource-group rg-alz-management \
     --workspace-name law-alz-management \
     --subscription $MGMT_SUB_ID
   ```

3. **Check hub networking:**
   ```bash
   az network vnet show \
     --name vnet-hub-primary \
     --resource-group rg-hub-networking \
     --subscription $CONN_SUB_ID
   ```

4. **Review policy assignments:**
   ```bash
   az policy assignment list \
     --scope "/providers/Microsoft.Management/managementGroups/alz" \
     --output table
   ```

### Step 6: Explore the Landing Zone

1. **View in Azure Portal:**
   - Navigate to Management Groups
   - Explore Policy assignments and compliance
   - Review deployed resources across subscriptions

2. **Test policy compliance:**
   ```bash
   az policy state list \
     --management-group alz \
     --output table
   ```

### Step 7: Clean Up

When ready to remove resources:

1. **Destroy the infrastructure:**
   ```bash
   terraform destroy \
     -var="management_subscription_id=$MGMT_SUB_ID" \
     -var="connectivity_subscription_id=$CONN_SUB_ID"
   ```

2. **Confirm destruction:**
   ```
   Enter a value: yes
   ```

## Key Learning Outcomes

After completing this lab, you will have learned:

- ✅ **Multi-Subscription Deployments**: How to use provider aliases to deploy resources across multiple Azure subscriptions within a single Terraform configuration
- ✅ **Azure Verified Modules**: Understanding and implementing Microsoft's official, tested, and supported Terraform modules for Azure services
- ✅ **Landing Zone Architecture**: Deploying enterprise-grade governance structure with management groups, policies, and role-based access control
- ✅ **Provider Composition**: Advanced Terraform patterns for complex provider configurations and module provider assignment
- ✅ **Azure Landing Zone (ALZ) Provider**: Leveraging specialized providers for Azure-specific governance and policy management
- ✅ **Cross-Subscription Resource References**: Managing dependencies and data sharing between resources deployed in different subscriptions
- ✅ **Enterprise Governance**: Implementing security policies, compliance controls, and centralized logging at scale
- ✅ **Hub-and-Spoke Networking**: Deploying foundational network architecture for enterprise workloads

## Questions

Consider these questions as you reflect on this lab:

1. **Subscription Strategy**: How would you decide which resources belong in the management subscription versus the connectivity subscription? What factors influence subscription boundaries in enterprise environments?

2. **Policy Governance**: The lab deploys numerous Azure policies automatically. How would you approach customizing these policies for different compliance requirements (HIPAA, SOC 2, ISO 27001) while maintaining operational efficiency?

3. **Module Versioning**: You used version constraints like `~> 0.13` for the Azure Verified Modules. How would you develop a strategy for keeping modules updated while maintaining stability in production environments?

4. **Provider Authentication**: This lab uses Azure CLI authentication. How would you adapt this pattern for automated CI/CD pipelines while maintaining security best practices and least-privilege access?

5. **Scaling Considerations**: As your organization grows, how would you extend this landing zone pattern to support multiple business units, regions, or environment types (dev/staging/prod) without configuration duplication?

6. **State Management**: The lab uses local state for simplicity. How would you implement this pattern with remote state management, considering the cross-subscription nature and potential team collaboration needs?

## Additional Resources

- [Azure Landing Zones Documentation](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [Cloud Adoption Framework](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/)
- [Azure Policy Documentation](https://docs.microsoft.com/en-us/azure/governance/policy/)
- [Terraform Provider Aliases](https://www.terraform.io/docs/language/providers/configuration.html#alias-multiple-provider-configurations)
- [Azure Landing Zone ALZ Provider](https://registry.terraform.io/providers/Azure/alz/latest/docs)
