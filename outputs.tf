output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "logic_app_name" {
  description = "Name of the Logic App"
  value       = azurerm_logic_app_workflow.main.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "trigger_url" {
  value     = data.azapi_resource_action.get_trigger_url.output.value
  sensitive = true
}
