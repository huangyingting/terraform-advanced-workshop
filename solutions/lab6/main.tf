terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  type    = string
  default = "southeastasia"
}

# Minimal block for import (fill name after manual creation)
resource "azurerm_virtual_network" "imported_vnet" {
  name                = "REPLACE-VNET-NAME"
  resource_group_name = "REPLACE-RG"
  location            = var.location
  address_space       = ["10.50.0.0/16"]
  dns_servers         = ["10.1.0.4"] # add real custom DNS to match existing
}
