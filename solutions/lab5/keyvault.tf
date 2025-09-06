# Example data source for retrieving secret (replace vault & secret names)

data "azurerm_key_vault" "kv" {
  name                = "REPLACE-keyvault"
  resource_group_name = "REPLACE-kv-rg"
}

data "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  key_vault_id = data.azurerm_key_vault.kv.id
}

# Example usage in a VM resource (not included here):
# admin_password = data.azurerm_key_vault_secret.vm_admin_password.value
