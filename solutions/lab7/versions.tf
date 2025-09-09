terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.108.0"
    }
  }
  # NOTE: Replace the placeholders below with your Terraform Cloud org/workspace
  # or manage this configuration via a CLI config file (.terraformrc) / TF_CLOUD_ORGANIZATION env var.
  cloud {
    organization = "REPLACE_WITH_TFC_ORG"
    workspaces {
      name = "lab7"
    }
  }
}

provider "azurerm" {
  features {}
}
