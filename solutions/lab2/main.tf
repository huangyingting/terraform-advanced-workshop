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
