provider "azurerm" {
  features {}
}

resource "azurerm_service_plan" "this" {
  name                = "${var.name}-plan"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.sku
  tags                = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = true
  tags                = var.tags
  site_config { ftps_state = "Disabled" }
  dynamic "identity" {
    for_each = var.enable_system_identity ? [1] : []
    content { type = "SystemAssigned" }
  }
}

output "web_app_id" { value = azurerm_linux_web_app.this.id }
output "default_hostname" { value = azurerm_linux_web_app.this.default_hostname }
