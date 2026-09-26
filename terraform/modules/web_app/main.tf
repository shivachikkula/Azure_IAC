# Linux web app (App Service) on an existing plan.

locals {
  stack = var.runtime_stack

  monitoring_settings = var.app_insights_connection_string == null ? {} : {
    APPLICATIONINSIGHTS_CONNECTION_STRING      = var.app_insights_connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
  }
}

resource "azurerm_linux_web_app" "this" {
  name                      = var.name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  service_plan_id           = var.service_plan_id
  https_only                = true
  client_affinity_enabled   = false
  virtual_network_subnet_id = var.vnet_subnet_id
  app_settings              = merge(local.monitoring_settings, var.app_settings)
  tags                      = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                         = var.always_on
    ftps_state                        = "Disabled"
    http2_enabled                     = true
    minimum_tls_version               = "1.2"
    scm_minimum_tls_version           = "1.2"
    app_command_line                  = var.startup_command
    health_check_path                 = var.health_check_path
    health_check_eviction_time_in_min = var.health_check_path == null ? null : 10
    vnet_route_all_enabled            = var.vnet_subnet_id != null

    application_stack {
      dotnet_version      = local.stack == "dotnet" ? var.runtime_version : null
      node_version        = local.stack == "node" ? var.runtime_version : null
      python_version      = local.stack == "python" ? var.runtime_version : null
      php_version         = local.stack == "php" ? var.runtime_version : null
      java_version        = local.stack == "java" ? var.runtime_version : null
      java_server         = local.stack == "java" ? "JAVA" : null
      java_server_version = local.stack == "java" ? var.runtime_version : null
    }

    dynamic "cors" {
      for_each = length(var.cors_allowed_origins) > 0 ? [1] : []
      content {
        allowed_origins = var.cors_allowed_origins
      }
    }
  }
}
