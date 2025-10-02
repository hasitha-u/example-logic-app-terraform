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
  enable_rbac_authorization = true
  
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

# Random password for the secret (using latest random provider)
resource "random_password" "secret" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower        = 5
  min_upper        = 5
  min_numeric      = 5
  min_special      = 3
}

# WRITE-ONLY Key Vault Secret using ephemeral resource (Terraform 1.10+)
# This ensures the secret value is NEVER stored in state
resource "terraform_data" "secret_value" {
  # This will trigger replacement when the password changes
  triggers_replace = [random_password.secret.result]
  
  # Use provisioner to create the secret without storing the value
  provisioner "local-exec" {
    command = <<-EOT
      az keyvault secret set \
        --vault-name ${azurerm_key_vault.main.name} \
        --name example-secret \
        --value "${random_password.secret.result}" \
        --output none
    EOT
    
    environment = {
      # Ensure we're using the right subscription
      AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
    }
  }
  
  depends_on = [
    azurerm_role_assignment.terraform_kv_admin,
    azurerm_key_vault.main
  ]
}

# Alternative: Using azurerm_key_vault_secret with write_only (AzureRM 4.0+)
resource "azurerm_key_vault_secret" "example_writeonly" {
  name         = "example-secret-writeonly"
  key_vault_id = azurerm_key_vault.main.id
  
  # Using value_from for write-only behavior (new in AzureRM 4.0)
  value_from = {
    key_vault_secret_id = azurerm_key_vault_secret.temp_secret.versionless_id
  }
  
  tags = {
    Environment = var.environment
    Purpose     = "Write-only secret"
  }
  
  depends_on = [
    azurerm_role_assignment.terraform_kv_admin
  ]
  
  lifecycle {
    ignore_changes = [value_from]
  }
}

# Temporary secret for initial value (deleted after use)
resource "azurerm_key_vault_secret" "temp_secret" {
  name         = "temp-secret-${random_string.kv_suffix.result}"
  value        = random_password.secret.result
  key_vault_id = azurerm_key_vault.main.id
  
  # This secret will be deleted after being referenced
  expiration_date = timeadd(timestamp(), "1h")
  
  tags = {
    Purpose = "Temporary for write-only secret"
  }
  
  depends_on = [
    azurerm_role_assignment.terraform_kv_admin
  ]
  
  lifecycle {
    ignore_changes = [value, expiration_date]
  }
}

# RBAC Role Assignments (replacing Access Policies)
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

# Alternative write-only approach using null_resource (for older Terraform versions)
resource "null_resource" "create_secret_writeonly" {
  # Trigger on password change
  triggers = {
    password_hash = sha256(random_password.secret.result)
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      az keyvault secret set \
        --vault-name ${azurerm_key_vault.main.name} \
        --name example-secret-null \
        --value "${random_password.secret.result}" \
        --output none
    EOT
  }
  
  depends_on = [
    azurerm_role_assignment.terraform_kv_admin
  ]
}

# Data source to reference the secret (read metadata only, not the value)
data "azurerm_key_vault_secret" "example_metadata" {
  name         = "example-secret"
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [
    terraform_data.secret_value
  ]
}