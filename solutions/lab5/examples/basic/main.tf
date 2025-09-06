terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.100.0"
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

resource "azurerm_resource_group" "example" {
  name     = "lab10-example-rg"
  location = var.location
}

module "web_app" {
  source              = "../../modules/web_app"
  name                = "lab10-example-web"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name
  tags = { module = "example" }
}

output "hostname" { value = module.web_app.default_hostname }
