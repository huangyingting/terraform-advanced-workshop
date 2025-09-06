terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "REPLACE-rg"
    storage_account_name = "REPLACEstorage"
    container_name       = "tfstate"
    key                  = "application.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}

variable "name_prefix" {
  type    = string
  default = "lab1app"
}
variable "location" {
  type    = string
  default = "southeastasia"
}

# Remote state from networking layer
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = "REPLACE-rg"
    storage_account_name = "REPLACEstorage"
    container_name       = "tfstate"
    key                  = "networking.tfstate"
    use_azuread_auth     = true
  }
}
