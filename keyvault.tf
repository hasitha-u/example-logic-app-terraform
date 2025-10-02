# Key Vault
resource "azurerm_key_vault" "main" {
  name                = "${var.project_name}${var.environment}kv${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name           = "standard"

  purge_protection_enabled    = false
  enabled_for_disk_encryption = false
  soft_delete_retention_days  = 7

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = {
    Environment = var.environment
    Owner       = var.user_name
  }
}

# Random string for Key Vault name uniqueness
resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Random password for the secret
resource "random_password" "secret" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Key Vault Secret (write-only)
resource "azurerm_key_vault_secret" "example" {
  name         = "example-secret"
  value        = random_password.secret.result
  key_vault_id = azurerm_key_vault.main.id

  # Lifecycle rule to prevent the secret value from being exposed in terraform plan
  lifecycle {
    ignore_changes = [value]
  }

  depends_on = [
    azurerm_key_vault_access_policy.terraform
  ]
}

# Access policy for Terraform deployment (current user/service principal)
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover"
  ]
}

# Access policy for Logic App Managed Identity
resource "azurerm_key_vault_access_policy" "logic_app" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.logic_app.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}