# Data source for current Azure configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location

  tags = {
    Environment = var.environment
    Owner       = var.user_name
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# User Assigned Managed Identity for Logic App
resource "azurerm_user_assigned_identity" "logic_app" {
  name                = "${var.project_name}-${var.environment}-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
    Owner       = var.user_name
    Purpose     = "Logic App Managed Identity"
  }
}

# Logic App Workflow
resource "azurerm_logic_app_workflow" "main" {
  name                = "${var.project_name}-${var.environment}-logic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.logic_app.id]
  }

  tags = {
    Environment = var.environment
    Owner       = var.user_name
    Project     = var.project_name
  }
}

# Update Logic App workflow definition using azapi
resource "azapi_update_resource" "workflow_definition" {
  type        = "Microsoft.Logic/workflows@2019-05-01"
  resource_id = azurerm_logic_app_workflow.main.id

  body = {
    properties = {
      state      = "Enabled"
      definition = jsondecode(file("${path.module}/workflow.json"))
      parameters = {
        "username" = {
          value = var.user_name
        }
        "environment" = {
          value = var.environment
        }
        "keyvault_uri" = {
          value = azurerm_key_vault.main.vault_uri
        }
        "secret_name" = {
          value = azurerm_key_vault_secret.example.name
        }
        "managed_identity_id" = {
          value = azurerm_user_assigned_identity.logic_app.id
        }
      }
    }
  }

  depends_on = [
    azurerm_logic_app_workflow.main,
    azurerm_role_assignment.logic_app_kv_secrets_user,
    azurerm_key_vault_secret.example
  ]
}