# Project root module: deploy only the services a project needs, into one resource group.
# Each project has a folder under terraform/projects/ with one .tfvars file per environment
# that switches services on with the deploy_* variables. The web apps share one Linux
# App Service Plan; the function app has its own Flex Consumption plan; Log Analytics +
# Application Insights are shared by all apps.

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  compact_name = replace(var.project_name, "-", "")
  suffix       = random_string.suffix.result

  needs_plan       = var.deploy_app_service || var.deploy_web_angular_api
  needs_monitoring = var.enable_monitoring && (var.deploy_app_service || var.deploy_web_angular_api || var.deploy_function_app)

  is_free_or_shared = can(regex("^[FfDd]", var.app_service_plan.sku_name))

  app_insights_connection_string = local.needs_monitoring ? module.monitoring[0].app_insights_connection_string : null

  tags = merge({
    application = var.project_name
    environment = var.environment
    managedBy   = "terraform"
  }, var.tags)
}

# Random suffix for globally unique names; stored in state so names stay stable.
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

# ---------- Shared resources ----------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_service_plan" "web" {
  count               = local.needs_plan ? 1 : 0
  name                = "asp-${local.name_prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Linux"
  sku_name            = var.app_service_plan.sku_name
  worker_count        = var.app_service_plan.instance_count
  tags                = local.tags
}

module "monitoring" {
  source              = "../modules/monitoring"
  count               = local.needs_monitoring ? 1 : 0
  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

# ---------- App Service ----------

module "app_service" {
  source                         = "../modules/web_app"
  count                          = var.deploy_app_service ? 1 : 0
  name                           = "app-${local.name_prefix}-${local.suffix}"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.this.name
  tags                           = local.tags
  service_plan_id                = azurerm_service_plan.web[0].id
  runtime_stack                  = var.app_service.runtime_stack
  runtime_version                = var.app_service.runtime_version
  startup_command                = var.app_service.startup_command
  health_check_path              = var.app_service.health_check_path
  app_settings                   = var.app_service.app_settings
  always_on                      = !local.is_free_or_shared
  app_insights_connection_string = local.app_insights_connection_string
}

# ---------- Angular client + .NET API ----------

module "client_app" {
  source              = "../modules/web_app"
  count               = var.deploy_web_angular_api ? 1 : 0
  name                = "app-${local.name_prefix}-web-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
  service_plan_id     = azurerm_service_plan.web[0].id
  runtime_stack       = "node"
  runtime_version     = var.web_angular_api.client_node_version
  # Serve the static Angular build and fall back to index.html for client-side routes
  startup_command                = "pm2 serve /home/site/wwwroot --no-daemon --spa"
  app_settings                   = var.web_angular_api.client_app_settings
  always_on                      = !local.is_free_or_shared
  app_insights_connection_string = local.app_insights_connection_string
}

module "api_app" {
  source                         = "../modules/web_app"
  count                          = var.deploy_web_angular_api ? 1 : 0
  name                           = "app-${local.name_prefix}-api-${local.suffix}"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.this.name
  tags                           = local.tags
  service_plan_id                = azurerm_service_plan.web[0].id
  runtime_stack                  = "dotnet"
  runtime_version                = var.web_angular_api.api_dotnet_version
  health_check_path              = var.web_angular_api.api_health_check_path
  app_settings                   = var.web_angular_api.api_app_settings
  always_on                      = !local.is_free_or_shared
  app_insights_connection_string = local.app_insights_connection_string
  cors_allowed_origins = distinct(concat(
    ["https://${module.client_app[0].default_hostname}"],
    var.web_angular_api.api_extra_cors_origins,
  ))
}

# ---------- Function App ----------

module "function_storage" {
  source                    = "../modules/storage_account"
  count                     = var.deploy_function_app ? 1 : 0
  name                      = substr("stfn${local.compact_name}${local.suffix}", 0, 24)
  location                  = var.location
  resource_group_name       = azurerm_resource_group.this.name
  tags                      = local.tags
  shared_access_key_enabled = var.function_app.storage_authentication == "ConnectionString"
}

module "function_app" {
  source                         = "../modules/function_app"
  count                          = var.deploy_function_app ? 1 : 0
  name                           = "func-${local.name_prefix}-${local.suffix}"
  plan_name                      = "asp-${local.name_prefix}-func"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.this.name
  tags                           = local.tags
  storage_account_id             = module.function_storage[0].id
  storage_account_name           = module.function_storage[0].name
  storage_primary_blob_endpoint  = module.function_storage[0].primary_blob_endpoint
  storage_access_key             = module.function_storage[0].primary_access_key
  storage_authentication         = var.function_app.storage_authentication
  runtime_name                   = var.function_app.runtime_name
  runtime_version                = var.function_app.runtime_version
  instance_memory_mb             = var.function_app.instance_memory_mb
  maximum_instance_count         = var.function_app.maximum_instance_count
  app_settings                   = var.function_app.app_settings
  app_insights_connection_string = local.app_insights_connection_string
}

# ---------- Storage account ----------

module "storage_account" {
  source                     = "../modules/storage_account"
  count                      = var.deploy_storage_account ? 1 : 0
  name                       = substr("st${local.compact_name}${var.environment}${local.suffix}", 0, 24)
  location                   = var.location
  resource_group_name        = azurerm_resource_group.this.name
  tags                       = local.tags
  replication_type           = var.storage_account.replication_type
  access_tier                = var.storage_account.access_tier
  shared_access_key_enabled  = var.storage_account.shared_access_key_enabled
  soft_delete_retention_days = var.storage_account.soft_delete_retention_days
  versioning_enabled         = var.storage_account.versioning_enabled
  containers                 = var.storage_account.containers
  queues                     = var.storage_account.queues
  tables                     = var.storage_account.tables
  file_shares                = var.storage_account.file_shares
}
