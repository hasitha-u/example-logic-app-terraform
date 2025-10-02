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

  workflow_parameters = {
    "$keyvault_name" = jsonencode({
      type         = "String"
      defaultValue = azurerm_key_vault.main.name
    })
    "$secret_name" = jsonencode({
      type         = "String"
      defaultValue = azurerm_key_vault_secret.example.name
    })
    "$tenant_id" = jsonencode({
      type         = "String"
      defaultValue = data.azurerm_client_config.current.tenant_id
    })
    "$subscription_id" = jsonencode({
      type         = "String"
      defaultValue = data.azurerm_client_config.current.subscription_id
    })
    "$resource_group" = jsonencode({
      type         = "String"
      defaultValue = azurerm_resource_group.main.name
    })
    "$managed_identity_client_id" = jsonencode({
      type         = "String"
      defaultValue = azurerm_user_assigned_identity.logic_app.client_id
    })
  }

  tags = {
    Environment = var.environment
    Owner       = var.user_name
  }

  depends_on = [
    azurerm_key_vault_access_policy.logic_app,
    azurerm_key_vault_secret.example
  ]
}

# Logic App Action Definition
resource "azurerm_resource_group_template_deployment" "logic_app_workflow" {
  name                = "${var.project_name}-${var.environment}-workflow-deployment"
  resource_group_name = azurerm_resource_group.main.name
  deployment_mode     = "Incremental"

  template_content = file("${path.module}/workflow.json")

  parameters_content = jsonencode({
    "logic_app_name" = {
      value = azurerm_logic_app_workflow.main.name
    }
    "keyvault_name" = {
      value = azurerm_key_vault.main.name
    }
    "secret_name" = {
      value = azurerm_key_vault_secret.example.name
    }
    "tenant_id" = {
      value = data.azurerm_client_config.current.tenant_id
    }
    "subscription_id" = {
      value = data.azurerm_client_config.current.subscription_id
    }
    "resource_group" = {
      value = azurerm_resource_group.main.name
    }
    "managed_identity_id" = {
      value = azurerm_user_assigned_identity.logic_app.id
    }
    "managed_identity_client_id" = {
      value = azurerm_user_assigned_identity.logic_app.client_id
    }
    "location" = {
      value = var.location
    }
  })

  depends_on = [
    azurerm_logic_app_workflow.main,
    azurerm_key_vault_access_policy.logic_app
  ]
}