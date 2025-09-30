locals {
  resource_prefix = "hello-world-${var.environment}"
  
  tags = {
    Environment = var.environment
    Project     = "HelloWorld"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.resource_prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_logic_app_workflow" "hello_world" {
  name                = "logic-${local.resource_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  

  identity {
    type = "SystemAssigned"
  }
  
  tags = local.tags
}

resource "azapi_update_resource" "workflow_definition" {
  type        = "Microsoft.Logic/workflows@2019-05-01"
  resource_id = azurerm_logic_app_workflow.hello_world.id
  
  body = {
    properties = {
      state = "Enabled"
      definition = jsondecode(file("${path.module}/workflow.json"))
      parameters = {
        "User" = {
          value = var.user_name
        }
        "Env" = {
          value = var.environment
        }
      }
    }
    
  }
  
  depends_on = [azurerm_logic_app_workflow.hello_world]
}


data "azapi_resource_action" "manual_callback" {
  type        = "Microsoft.Logic/workflows/triggers@2019-05-01"
  resource_id = "${azurerm_logic_app_workflow.hello_world.id}/triggers/manual"
  action      = "listCallbackUrl"
  method      = "POST"

  response_export_values = ["value"]

  # Ensure the definition is applied before asking for the URL
  depends_on = [azapi_update_resource.workflow_definition]
}

