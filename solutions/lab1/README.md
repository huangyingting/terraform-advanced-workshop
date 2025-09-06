# Lab 1: Remote State & Layered Architecture

## Overview
This lab demonstrates enterprise-grade Terraform state management using Azure Blob Storage as a remote backend with separated backend configuration files. You'll implement a layered architecture pattern where infrastructure and application components are split into logical tiers that share data through remote state data sources. The lab showcases how to use `.tfbackend` files for flexible backend configuration, eliminating hardcoded values and enabling environment-specific deployments.

## Prerequisites

### Required Permissions
- **Azure Subscription**: Contributor or Owner role
- **Storage Account**: Data Contributor role (for blob operations)
- **Resource Groups**: Contributor role (to create and manage resources)

### Required Tools
- Azure CLI v2.50+ authenticated and configured
- Terraform v1.7+ installed
- SSH key pair for VM access (or Azure CLI will generate one)
- Git for version control
- VS Code with Terraform extension (recommended)

### Environment Setup
```bash
# Verify Azure CLI authentication
az account show

# Set default location (optional)
export TF_VAR_location="southeastasia"

# Set subscription ID
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

## Step-by-Step Instructions

### Step 1: Prepare the Lab Environment

1. **Navigate to the lab directory:**
   ```bash
   cd solutions/lab1
   ```

2. **Run the preparation script:**
   ```bash
   chmod +x prepare.sh
   ./prepare.sh
   ```

   The `prepare.sh` script will:
   - Create a resource group for state storage
   - Create a storage account with unique naming
   - Create a blob container named `tfstate`
   - Generate separated backend configuration files:
     - `infrastructure/infrastructure.tfbackend`
     - `application/application.tfbackend`
     - `application/terraform.tfvars`
   - Configure versioning and security settings

   Environment variable overrides (all optional):
   ```bash
   RESOURCE_GROUP=my-tf-rg LOCATION=westeurope ./prepare.sh
   ```

### Step 2: Deploy the Infrastructure Layer

1. **Navigate to infrastructure directory and initialize:**
   ```bash
   cd infrastructure
   
   # Initialize Terraform with backend config file
   terraform init -backend-config=infrastructure.tfbackend
   
   # Review the configuration
   terraform plan
   
   # Deploy the infrastructure
   terraform apply -auto-approve
   
   # Verify outputs
   terraform output
   ```

2. **Verify the remote state:**
   ```bash
   # Check that state file exists in blob storage
   STORAGE_ACCOUNT=$(grep storage_account_name infrastructure.tfbackend | cut -d'"' -f2)
   RESOURCE_GROUP=$(grep resource_group_name infrastructure.tfbackend | cut -d'"' -f2)
   
   az storage blob list \
     --account-name $STORAGE_ACCOUNT \
     --container-name tfstate \
     --output table
   ```

### Step 3: Deploy the Application Layer

1. **Navigate to application directory and deploy:**
   ```bash
   cd ../application
   
   # Initialize with backend config file
   terraform init -backend-config=application.tfbackend
   
   # Verify remote state access
   terraform refresh
   
   # Plan the deployment
   terraform plan
   
   # Deploy the application
   terraform apply -auto-approve
   
   # Display outputs including SSH command
   terraform output
   ```

2. **Test the SSH connection:**
   ```bash
   # Get the SSH command from output
   SSH_COMMAND=$(terraform output -raw ssh_connection_command)
   echo "SSH Command: $SSH_COMMAND"
   
   # Test the connection (optional)
   # eval $SSH_COMMAND "sudo apt update && sudo apt install -y nginx"
   ```

### Step 4: Verify the Architecture

1. **Check separated state files:**
   ```bash
   # List all state files in blob storage
   az storage blob list \
     --account-name $STORAGE_ACCOUNT \
     --container-name tfstate \
     --output table
   
   # Should show:
   # - infrastructure.tfstate
   # - application.tfstate
   ```

2. **Verify cross-layer data sharing:**
   ```bash
   cd application
   terraform console << 'EOF'
   data.terraform_remote_state.network.outputs
   EOF
   ```

### Step 5: Clean Up

When ready to clean up:

1. **Destroy application layer:**
   ```bash
   cd application
   terraform destroy -auto-approve
   ```

2. **Destroy infrastructure layer:**
   ```bash
   cd ../infrastructure
   terraform destroy -auto-approve
   ```

3. **Remove state storage (optional):**
   ```bash
   # Delete the storage account and resource group
   RESOURCE_GROUP=$(grep resource_group_name infrastructure.tfbackend | cut -d'"' -f2)
   az group delete --name $RESOURCE_GROUP --yes --no-wait
   ```

## Key Learning Outcomes

After completing this lab, you will have learned:

- ✅ **Separated Backend Configuration**: How to use `.tfbackend` files to eliminate hardcoded backend values
- ✅ **Layered Architecture**: Implementing infrastructure and application layers with proper separation of concerns
- ✅ **Remote State Management**: Configuring Azure Blob Storage as a secure remote backend with state locking
- ✅ **Cross-Layer Data Sharing**: Using remote state data sources to share outputs between Terraform configurations
- ✅ **Partial Backend Configuration**: Leveraging Terraform's partial backend configuration for flexibility
- ✅ **State File Organization**: Managing multiple state files for different architectural layers
- ✅ **Enterprise Patterns**: Implementing production-ready Terraform state management practices

## Thoughtful Questions

Consider these questions as you reflect on this lab:

1. **Architecture Design**: How would you modify this pattern to support multiple environments (dev, staging, prod) without duplicating configuration files?

2. **State Management**: What are the trade-offs between having separate state files per layer versus a single monolithic state file?

3. **Security Considerations**: How could you implement different access controls for infrastructure vs application teams using this pattern?

4. **CI/CD Integration**: How would you adapt this backend configuration approach for automated deployment pipelines?

5. **Scalability**: As your infrastructure grows to include databases, monitoring, and networking layers, how would you organize the state files and dependencies?

6. **Recovery Scenarios**: If the infrastructure state file becomes corrupted, how would you recover while minimizing impact on the application layer?

## Additional Resources

- [Terraform Backend Configuration](https://www.terraform.io/docs/language/backend/index.html)
- [Azure Storage Backend](https://www.terraform.io/docs/language/backend/azurerm.html)  
- [Remote State Data Source](https://www.terraform.io/docs/language/state/remote-state-data.html)
- [Partial Backend Configuration](https://www.terraform.io/docs/language/backend/azurerm.html#partial-configuration)
- [Azure Blob Storage Versioning](https://docs.microsoft.com/en-us/azure/storage/blobs/versioning-overview)
- [Terraform State Locking](https://www.terraform.io/docs/language/state/locking.html)

- [Terraform Backend Configuration](https://www.terraform.io/docs/language/backend/index.html)
- [Azure Storage Backend](https://www.terraform.io/docs/language/backend/azurerm.html)
- [Remote State Data Source](https://www.terraform.io/docs/language/state/remote-state-data.html)
- [State Locking](https://www.terraform.io/docs/language/state/locking.html)
- [Azure Blob Storage Versioning](https://docs.microsoft.com/en-us/azure/storage/blobs/versioning-overview)

