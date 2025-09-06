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

variable "tag_name" {
  type    = string
  default = "cost-center"
}
variable "tag_value" {
  type    = string
  default = "demo"
}

# Policy Definitions
resource "azurerm_policy_definition" "require_tag" {
  name         = "require-tag-demo"
  display_name = "Require Tag Demo"
  policy_type  = "Custom"
  mode         = "Indexed"
  policy_rule  = file("${path.module}/policies/require-tag.json")
  parameters = <<PARAMS
{
  "tagName": {"value": "${var.tag_name}"},
  "tagValue": {"value": "${var.tag_value}"}
}
PARAMS
}

resource "azurerm_policy_definition" "ensure_ama" {
  name         = "ensure-ama-demo"
  display_name = "Ensure AMA Installed"
  policy_type  = "Custom"
  mode         = "Indexed"
  policy_rule  = file("${path.module}/policies/ensure-ama.json")
}

# Initiative
resource "azurerm_policy_set_definition" "initiative" {
  name         = "demo-initiative"
  display_name = "Demo Initiative"
  policy_type  = "Custom"
  metadata     = jsonencode({ category = "Demo" })

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_tag.id
    parameter_values = jsonencode({
      tagName  = { value = var.tag_name }
      tagValue = { value = var.tag_value }
    })
  }
  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.ensure_ama.id
  }
}

data "azurerm_subscription" "current" {}

resource "azurerm_subscription_policy_assignment" "initiative" {
  name                 = "demo-initiative-assignment"
  display_name         = "Demo Initiative Assignment"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_set_definition.initiative.id
}

output "initiative_id" { value = azurerm_policy_set_definition.initiative.id }
