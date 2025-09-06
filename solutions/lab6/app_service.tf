# Copilot-generated (example) then hardened manually

resource "azurerm_service_plan" "asp" {
  name                = "lab6-asp"
  location            = var.location
  resource_group_name = "REPLACE-RG"
  os_type             = "Linux"
  sku_name            = "B1"
  tags = { environment = "lab6" }
}

resource "azurerm_linux_web_app" "web" {
  name                = "lab6-webapp"
  location            = var.location
  resource_group_name = azurerm_service_plan.asp.resource_group_name
  service_plan_id     = azurerm_service_plan.asp.id
  https_only          = true
  tags = { environment = "lab6" }

  site_config {
    ftps_state = "Disabled"
    always_on  = true
  }
}

resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.web.id
  site_config {
    ftps_state = "Disabled"
  }
  tags = { environment = "lab6-staging" }
}
