data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "aum" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.aum.location
  resource_group_name = azurerm_resource_group.aum.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization = true
}

resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.aum.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# A fresh role assignment takes a few seconds to propagate. Without
# this, the next resource (writing the secret) can fail intermittently
# with an authorization error even though the assignment "exists."
resource "time_sleep" "rbac_propagation" {
  depends_on      = [azurerm_role_assignment.deployer_secrets_officer]
  create_duration = "30s"
}

resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.aum.id

  depends_on = [time_sleep.rbac_propagation]
}