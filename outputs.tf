output "trigger_url" {
  value     = data.azapi_resource_action.manual_callback.output.value
  sensitive = true
}