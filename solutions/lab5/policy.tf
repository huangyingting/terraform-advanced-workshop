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

variable "allowed_sizes" {
  type    = list(string)
  default = ["Standard_B1s", "Standard_B2s"]
}

data "azurerm_subscription" "current" {}

resource "azurerm_policy_definition" "restrict_vm_size" {
  name         = "restrict-vm-size"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Restrict VM Sizes"
  description  = "Only allow specific VM sizes"
  policy_rule  = <<POLICY
{
  "if": {
    "allOf": [
      {"field": "type", "equals": "Microsoft.Compute/virtualMachines"},
      {"not": {"field": "Microsoft.Compute/virtualMachines/sku.name", "in": ${jsonencode(var.allowed_sizes)} }}
    ]
  },
  "then": {"effect": "deny"}
}
POLICY
}

resource "azurerm_subscription_policy_assignment" "restrict_vm_size" {
  name                 = "restrict-vm-size"
  policy_definition_id = azurerm_policy_definition.restrict_vm_size.id
  subscription_id      = data.azurerm_subscription.current.id
  display_name         = "Restrict VM Sizes"
}
