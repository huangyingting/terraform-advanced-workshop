terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.100.0"
    }
    random = {
      source = "hashicorp/random"
      version = ">=3.5.0"
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
variable "prefix" {
  type    = string
  default = "lab9"
}

resource "azurerm_resource_group" "net" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# Hub + workload VNet (simplified single VNet for demo)
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name
  address_space       = ["10.60.0.0/16"]
}
resource "azurerm_subnet" "workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.60.1.0/24"]
}

# Placeholder private endpoint target resources (user supplies existing storage, key vault, acr)
variable "storage_account_id" { type = string }
variable "key_vault_id" { type = string }
variable "acr_id" { type = string }

variable "create_test_vm" {
  description = "Whether to create a test VM to validate private endpoint access"
  type        = bool
  default     = true
}

# Private DNS Zones
locals {
  pe_zones = {
    blob     = "privatelink.blob.core.windows.net"
    vault    = "privatelink.vaultcore.azure.net"
    acr      = "privatelink.azurecr.io"
  }
}
resource "azurerm_private_dns_zone" "zones" {
  for_each            = local.pe_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.net.name
}
resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = local.pe_zones
  name                  = "${each.key}-link"
  resource_group_name   = azurerm_resource_group.net.name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Private Endpoints
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "${var.prefix}-pe-blob"
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name
  subnet_id           = azurerm_subnet.workload.id

  private_service_connection {
    name                           = "${var.prefix}-blob-conn"
    private_connection_resource_id = var.storage_account_id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  depends_on = [azurerm_private_dns_zone.zones]
}
resource "azurerm_private_dns_zone_group" "storage_blob" {
  name                 = "blob-zone-group"
  private_endpoint_id  = azurerm_private_endpoint.storage_blob.id
  private_dns_zone_configs {
    name                  = "blob-zone"
    private_dns_zone_id   = azurerm_private_dns_zone.zones["blob"].id
  }
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "${var.prefix}-pe-kv"
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name
  subnet_id           = azurerm_subnet.workload.id

  private_service_connection {
    name                           = "${var.prefix}-kv-conn"
    private_connection_resource_id = var.key_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  depends_on = [azurerm_private_dns_zone.zones]
}
resource "azurerm_private_dns_zone_group" "key_vault" {
  name                 = "kv-zone-group"
  private_endpoint_id  = azurerm_private_endpoint.key_vault.id
  private_dns_zone_configs {
    name                = "kv-zone"
    private_dns_zone_id = azurerm_private_dns_zone.zones["vault"].id
  }
}

resource "azurerm_private_endpoint" "acr" {
  name                = "${var.prefix}-pe-acr"
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name
  subnet_id           = azurerm_subnet.workload.id

  private_service_connection {
    name                           = "${var.prefix}-acr-conn"
    private_connection_resource_id = var.acr_id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  depends_on = [azurerm_private_dns_zone.zones]
}
resource "azurerm_private_dns_zone_group" "acr" {
  name                 = "acr-zone-group"
  private_endpoint_id  = azurerm_private_endpoint.acr.id
  private_dns_zone_configs {
    name                = "acr-zone"
    private_dns_zone_id = azurerm_private_dns_zone.zones["acr"].id
  }
}

# Test VM (optional)
resource "random_password" "vm" {
  length  = 16
  special = true
}

resource "azurerm_network_interface" "vm" {
  count               = var.create_test_vm ? 1 : 0
  name                = "${var.prefix}-vm-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.create_test_vm ? 1 : 0
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.net.name
  location            = var.location
  size                = "Standard_B1ms"
  admin_username      = "azureuser"
  admin_password      = random_password.vm.result
  disable_password_authentication = false
  network_interface_ids = [azurerm_network_interface.vm[0].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Outputs
output "vnet_id" { value = azurerm_virtual_network.vnet.id }
output "private_endpoint_ids" {
  value = {
    blob  = azurerm_private_endpoint.storage_blob.id
    vault = azurerm_private_endpoint.key_vault.id
    acr   = azurerm_private_endpoint.acr.id
  }
}
output "vm_private_ip" {
  value       = try(azurerm_network_interface.vm[0].ip_configuration[0].private_ip_address, null)
  description = "Private IP of test VM (if created)"
}
output "vm_password" {
  value       = random_password.vm.result
  sensitive   = true
  description = "Password for azureuser on test VM"
}
