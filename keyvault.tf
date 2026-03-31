# Random string for Key Vault name uniqueness
resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Key Vault with RBAC authorization
resource "azurerm_key_vault" "main" {
  name                = "${var.project_name}${var.environment}kv${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name           = "standard"

  # Use RBAC instead of access policies (recommended)
  rbac_authorization_enabled = true
  
  purge_protection_enabled    = var.enable_purge_protection
  enabled_for_disk_encryption = false
  soft_delete_retention_days  = 7

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = {
    Environment = var.environment
    Owner       = var.user_name
    Purpose     = "Secret Storage"
  }
}

# This password is not stored in state
ephemeral "random_password" "ephemeral_secret" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower        = 5
  min_upper        = 5
  min_numeric      = 5
  min_special      = 3
}

# Write-Only Secret using value_wo. The secret value is not stored in state.
resource "azurerm_key_vault_secret" "example" {
  name         = "ephemeral-secret"
  key_vault_id = azurerm_key_vault.main.id
  
  # Using ephemeral password with write-only
  value_wo         = ephemeral.random_password.ephemeral_secret.result
  value_wo_version = "1"
  
  tags = {
    Environment = var.environment
    Purpose     = "Ephemeral write-only secret"
  }
  
  depends_on = [
    azurerm_role_assignment.terraform_kv_admin
  ]
}

# RBAC Role Assignments
# Terraform deployment identity - Key Vault Administrator
resource "azurerm_role_assignment" "terraform_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Logic App Managed Identity - Key Vault Secrets User (read-only)
resource "azurerm_role_assignment" "logic_app_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.logic_app.principal_id
}

data "azapi_resource_action" "get_trigger_url" {
  type        = "Microsoft.Logic/workflows/triggers@2019-05-01"
  resource_id = "${azurerm_logic_app_workflow.main.id}/triggers/manual"
  action      = "listCallbackUrl"
  method      = "POST"

  response_export_values = ["value"]

  # Ensure the definition is applied before asking for the URL
  depends_on = [azapi_update_resource.workflow_definition]
}

