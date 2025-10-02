output "trigger_url" {
  description = "Trigger URL for the Logic App"
  value       = azurerm_logic_app_workflow.main.access_endpoint
  sensitive   = true
}
