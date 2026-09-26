# Function App on a Flex Consumption plan (Linux, serverless, scales to zero).
# Uses an existing storage account for the Functions runtime and creates the
# blob container that holds the deployment package.

locals {
  use_identity = var.storage_authentication == "ManagedIdentity"

  # Built-in roles the Functions runtime needs when it uses its managed identity
  storage_role_names = [
    "Storage Blob Data Owner",
    "Storage Queue Data Contributor",
    "Storage Table Data Contributor",
  ]
}

resource "azurerm_service_plan" "this" {
  name                = var.plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = var.tags
}

resource "azurerm_storage_container" "package" {
  name                  = "app-package"
  storage_account_id    = var.storage_account_id
  container_access_type = "private"
}

resource "azurerm_function_app_flex_consumption" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = true
  tags                = var.tags

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${var.storage_primary_blob_endpoint}${azurerm_storage_container.package.name}"
  storage_authentication_type = local.use_identity ? "SystemAssignedIdentity" : "StorageAccountConnectionString"
  storage_access_key          = local.use_identity ? null : var.storage_access_key

  runtime_name           = var.runtime_name
  runtime_version        = var.runtime_version
  instance_memory_in_mb  = var.instance_memory_mb
  maximum_instance_count = var.maximum_instance_count

  app_settings = merge(
    local.use_identity ? { AzureWebJobsStorage__accountName = var.storage_account_name } : {},
    var.app_settings,
  )

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version                    = "1.2"
    application_insights_connection_string = var.app_insights_connection_string
  }
}

resource "azurerm_role_assignment" "storage" {
  for_each             = local.use_identity ? toset(local.storage_role_names) : toset([])
  scope                = var.storage_account_id
  role_definition_name = each.value
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
