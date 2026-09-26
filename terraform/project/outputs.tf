# Outputs are null for services that are switched off.

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "app_service_name" {
  value = one(module.app_service[*].name)
}

output "app_service_url" {
  value = var.deploy_app_service ? "https://${module.app_service[0].default_hostname}" : null
}

output "client_app_name" {
  value = one(module.client_app[*].name)
}

output "client_url" {
  value = var.deploy_web_angular_api ? "https://${module.client_app[0].default_hostname}" : null
}

output "api_app_name" {
  value = one(module.api_app[*].name)
}

output "api_url" {
  value = var.deploy_web_angular_api ? "https://${module.api_app[0].default_hostname}" : null
}

output "function_app_name" {
  value = one(module.function_app[*].name)
}

output "function_app_url" {
  value = var.deploy_function_app ? "https://${module.function_app[0].default_hostname}" : null
}

output "storage_account_name" {
  value = one(module.storage_account[*].name)
}
