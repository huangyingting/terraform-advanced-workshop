terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.108.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_cli  = false
  use_oidc = true
}
