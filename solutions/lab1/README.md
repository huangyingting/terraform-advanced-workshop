# Lab 1: Remote State & Layered Architecture

## Overview
This lab demonstrates enterprise-grade Terraform state management using Azure Blob Storage as a remote backend with state locking, versioning, and soft delete. You'll learn how to implement a layered architecture pattern where infrastructure is split into logical tiers that share data through remote state data sources.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Azure Subscription                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┤
│  │               Foundation Layer                              │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │  Resource Group: rg-terraform-state                     │
│  │  │  ┌─────────────────────────────────────────────────────┤
│  │  │  │  Storage Account: sttfstate[random]                 │
│  │  │  │  ├── Container: tfstate                             │
│  │  │  │  │   ├── backend.tfstate (foundation config)       │
│  │  │  │  │   ├── networking.tfstate                        │
│  │  │  │  │   └── application.tfstate                       │
│  │  │  │  ├── Versioning: Enabled                           │
│  │  │  │  ├── Soft Delete: 30 days                          │
│  │  │  │  └── State Locking: Blob lease mechanism           │
│  │  │  └─────────────────────────────────────────────────────┘
│  │  └─────────────────────────────────────────────────────────┘
│  │                                                             │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │               Networking Layer                          │
│  │  │  ┌─────────────────────────────────────────────────────┤
│  │  │  │  Resource Group: rg-networking                      │
│  │  │  │  ├── Virtual Network: vnet-main (10.0.0.0/16)      │
│  │  │  │  ├── Subnet: subnet-app (10.0.1.0/24)              │
│  │  │  │  ├── Network Security Group: nsg-app               │
│  │  │  │  └── NSG Association                                │
│  │  │  └─────────────────────────────────────────────────────┘
│  │  └─────────────────────────────────────────────────────────┘
│  │                                                             │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │               Application Layer                         │
│  │  │  ┌─────────────────────────────────────────────────────┤
│  │  │  │  Resource Group: rg-application                     │
│  │  │  │  ├── Linux VM: vm-app-001                           │
│  │  │  │  ├── Network Interface: nic-vm-app-001              │
│  │  │  │  ├── OS Disk: Premium SSD                           │
│  │  │  │  ├── Data Disk: Standard SSD (optional)             │
│  │  │  │  └── NSG: Allow SSH from specific IP               │
│  │  │  └─────────────────────────────────────────────────────┘
│  │  └─────────────────────────────────────────────────────────┘
│  └─────────────────────────────────────────────────────────────┘
│                                                                 │
│  Data Flow:                                                     │
│  networking.tfstate → outputs subnet_id                        │
│  application.tfstate → data "terraform_remote_state" → subnet_id│
└─────────────────────────────────────────────────────────────────┘
```

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

# Set default location
export TF_VAR_location="southeastasia"

# Set subscription ID
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

```

## Directory Structure
```
lab1/
├── prepare.sh              # Bootstrap script for backend setup
├── infrastructure/         # Foundation layer (backend setup)
│   └── main.tf
├── application/            # Application layer
│   ├── main.tf
│   └── data.tf            # Remote state data source
└── README.md              # This file
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
   - Replace placeholders in configuration files
   - Configure versioning and security settings

   Environment variable overrides (all optional):
   ```bash
   RESOURCE_GROUP=my-tf-rg LOCATION=westeurope STORAGE_ACCOUNT=customtfstate123 ./prepare.sh
   ```

### Step 2: Set Required Environment Variables

Before running `terraform init`, you need to set your Azure subscription ID:

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
```

1. **Deploy the networking infrastructure:**
   ```bash
   cd infrastructure
   
   # Initialize Terraform with remote backend
   terraform init
   
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
   STORAGE_ACCOUNT=$(az storage account list --resource-group rg-terraform-state --query "[0].name" --output tsv)
   az storage blob list \
     --account-name $STORAGE_ACCOUNT \
     --container-name tfstate \
     --output table
   ```

### Step 4: Deploy the Application Layer

1. **Navigate to application directory and deploy:**
   ```bash
   cd ../application
   
   # Initialize with remote backend
   terraform init
   
   # Verify remote state access
   terraform refresh
   
   # Plan the deployment
   terraform plan
   
   # Deploy the infrastructure
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
   # eval $SSH_COMMAND "sudo apt update && sudo apt install -y nginx && sudo systemctl start nginx"
   ```

## Key Terraform Patterns Demonstrated

### 1. Remote Backend Configuration
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstateXXXXXX"
    container_name       = "tfstate"
    key                  = "networking.tfstate"
  }
}
```

### 2. Remote State Data Source
```hcl
data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstateXXXXXX"
    container_name       = "tfstate"
    key                  = "networking.tfstate"
  }
}
```

### 3. Cross-Layer Resource References
```hcl
resource "azurerm_network_interface" "vm" {
  # Reference subnet from networking layer
  ip_configuration {
    subnet_id = data.terraform_remote_state.networking.outputs.app_subnet_id
  }
}
```

### 4. State Management Features
- **State Locking**: Automatic blob lease mechanism prevents concurrent modifications
- **Versioning**: Storage account versioning provides rollback capabilities
- **Soft Delete**: 30-day retention for deleted state files
- **Encryption**: Server-side encryption for state file security

## Verification Steps

### Verify Remote State Setup
```bash
# List all state files in blob storage
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name tfstate \
  --output table

# Check networking state
cd infrastructure
terraform state list

# Check application state
cd ../application
terraform state list

# Verify remote state data access
terraform console << 'EOF'
data.terraform_remote_state.networking.outputs
EOF
```

### Test Infrastructure
```bash
# Get VM public IP
VM_IP=$(terraform output -raw vm_public_ip)
echo "VM Public IP: $VM_IP"

# Test network connectivity
ping -c 3 $VM_IP || echo "VM might not be responding to ping"

# Check SSH port
nc -zv $VM_IP 22
```

## Troubleshooting

### Common Issues and Solutions

#### Backend Configuration Issues
**Error**: `Failed to configure the backend "azurerm"`

**Solution**:
```bash
# Verify storage account exists and is accessible
az storage account show --name $STORAGE_ACCOUNT --resource-group rg-terraform-state

# Check container exists
az storage container show --name tfstate --account-name $STORAGE_ACCOUNT

# Verify permissions
az role assignment list --assignee $(az account show --query user.name -o tsv) --resource-group rg-terraform-state
```

#### Remote State Access Issues
**Error**: `Error loading state: blob doesn't exist`

**Solution**:
```bash
# Verify the networking layer has been deployed first
cd infrastructure
terraform state list

# Check the exact state file name in storage
az storage blob list --container-name tfstate --account-name $STORAGE_ACCOUNT --output table
```

#### SSH Key Issues
**Error**: SSH authentication failures

**Solution**:
```bash
# Check if SSH key was created correctly
ls -la ~/.ssh/
ls -la ./lab_ssh_key.pem

# Verify SSH key in VM configuration
terraform show | grep -A 5 "public_key"

# Test SSH key format
ssh-keygen -l -f ~/.ssh/id_rsa.pub 2>/dev/null || echo "Key file issue"
```

#### State Locking Issues
**Error**: `Error acquiring the state lock`

**Solution**:
```bash
# Check for existing locks
az storage blob list --container-name tfstate --account-name $STORAGE_ACCOUNT --include u --output table

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### State Management Best Practices

1. **Backup Strategy**:
   ```bash
   # Manual state backup
   terraform state pull > terraform.tfstate.backup
   
   # Verify storage account versioning
   az storage blob list --container-name tfstate --account-name $STORAGE_ACCOUNT --include v
   ```

2. **State File Security**:
   ```bash
   # Check access permissions
   az storage container show-permission --name tfstate --account-name $STORAGE_ACCOUNT
   
   # Verify encryption
   az storage account show --name $STORAGE_ACCOUNT --query "encryption"
   ```

## Clean Up

When you're ready to clean up the resources:

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
   cd ..
   
   # Delete the storage account and resource group
   az group delete --name rg-terraform-state --yes --no-wait
   ```

⚠️ **Note**: Always destroy in reverse dependency order (application → infrastructure → foundation).

## Key Learning Outcomes

After completing this lab, you'll have:
- ✅ Production-ready remote state configuration
- ✅ Understanding of layered architecture patterns
- ✅ Experience with cross-layer data sharing
- ✅ State locking and versioning implementation
- ✅ Security best practices for state files
- ✅ Troubleshooting skills for remote state issues

## Next Steps

Consider exploring:
- Terraform workspaces for environment isolation
- State encryption and access control patterns
- Automated state management in CI/CD pipelines
- Advanced backend configurations (partial backend config)
- State migration strategies

## Additional Resources

- [Terraform Backend Configuration](https://www.terraform.io/docs/language/backend/index.html)
- [Azure Storage Backend](https://www.terraform.io/docs/language/backend/azurerm.html)
- [Remote State Data Source](https://www.terraform.io/docs/language/state/remote-state-data.html)
- [State Locking](https://www.terraform.io/docs/language/state/locking.html)
- [Azure Blob Storage Versioning](https://docs.microsoft.com/en-us/azure/storage/blobs/versioning-overview)

