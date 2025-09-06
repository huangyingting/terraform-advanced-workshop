# Backend configuration for production environment
# This file should be copied to the root directory when deploying production

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-production"
    storage_account_name = "sttfstatelab3production" # Replace with actual storage account name
    container_name       = "tfstate"
    key                  = "production.tfstate"

    # Enable state locking
    use_msi = false
  }
}

# Note: The storage account and container should be created manually or via a separate bootstrap process
# Example Azure CLI commands:
#
# az group create --name rg-terraform-state-production --location southeastasia
# 
# az storage account create \
#   --name sttfstatelab3production \
#   --resource-group rg-terraform-state-production \
#   --location southeastasia \
#   --sku Standard_GRS \
#   --kind StorageV2 \
#   --allow-blob-public-access false \
#   --min-tls-version TLS1_2
#
# az storage container create \
#   --name tfstate \
#   --account-name sttfstatelab3production \
#   --auth-mode login
