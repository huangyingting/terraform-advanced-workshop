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

variable "primary_region" {
  type    = string
  default = "southeastasia"
}
variable "secondary_region" {
  type    = string
  default = "westus"
}
variable "app_name" {
  type    = string
  default = "lab7drapp"
}

locals {
  regions = {
    primary   = var.primary_region
    secondary = var.secondary_region
  }
}

# Resource groups per region
resource "azurerm_resource_group" "rg" {
  for_each = local.regions
  name     = "${var.app_name}-${each.key}-rg"
  location = each.value
}

# App Service Plans per region (secondary scaled smaller)
resource "azurerm_service_plan" "plan" {
  for_each            = local.regions
  name                = "${var.app_name}-${each.key}-plan"
  location            = azurerm_resource_group.rg[each.key].location
  resource_group_name = azurerm_resource_group.rg[each.key].name
  os_type             = "Linux"
  sku_name            = each.key == "primary" ? "B1" : "F1"
}

resource "azurerm_linux_web_app" "web" {
  for_each            = local.regions
  name                = "${var.app_name}-${each.key}-web"
  location            = azurerm_resource_group.rg[each.key].location
  resource_group_name = azurerm_resource_group.rg[each.key].name
  service_plan_id     = azurerm_service_plan.plan[each.key].id
  https_only          = true
  site_config { ftps_state = "Disabled" }
  app_settings = {
    REGION_ROLE = each.key
  }
}

# Traffic Manager for priority routing (could use Front Door instead)
resource "azurerm_traffic_manager_profile" "dr" {
  name                   = "${var.app_name}-tm"
  resource_group_name    = azurerm_resource_group.rg["primary"].name
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = var.app_name
    ttl           = 30
  }

  monitor_config {
    protocol = "HTTPS"
    port     = 443
    path     = "/"
  }
}

resource "azurerm_traffic_manager_endpoint" "primary" {
  name                = "primary-endpoint"
  profile_id          = azurerm_traffic_manager_profile.dr.id
  type                = "azureEndpoints"
  target_resource_id  = azurerm_linux_web_app.web["primary"].id
  priority            = 1
}
resource "azurerm_traffic_manager_endpoint" "secondary" {
  name                = "secondary-endpoint"
  profile_id          = azurerm_traffic_manager_profile.dr.id
  type                = "azureEndpoints"
  target_resource_id  = azurerm_linux_web_app.web["secondary"].id
  priority            = 2
}

output "traffic_manager_fqdn" { value = azurerm_traffic_manager_profile.dr.fqdn }
