# Backend configuration for staging environment
# This file should be copied to the root directory when deploying staging

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-staging"
    storage_account_name = "sttfstatelab3staging" # Replace with actual storage account name
    container_name       = "tfstate"
    key                  = "staging.tfstate"

    # Enable state locking
    use_msi = false
  }
}

# Note: The storage account and container should be created manually or via a separate bootstrap process
# Example Azure CLI commands:
#
# az group create --name rg-terraform-state-staging --location southeastasia
# 
# az storage account create \
#   --name sttfstatelab3staging \
#   --resource-group rg-terraform-state-staging \
#   --location southeastasia \
#   --sku Standard_LRS \
#   --kind StorageV2 \
#   --allow-blob-public-access false \
#   --min-tls-version TLS1_2
#
# az storage container create \
#   --name tfstate \
#   --account-name sttfstatelab3staging \
#   --auth-mode login
