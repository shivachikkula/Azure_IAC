# ---------- Resource group ----------

variable "resource_group_name" {
  description = "Name of the resource group to create for this project."
  type        = string
}

variable "location" {
  description = "Azure region for the resource group and all resources."
  type        = string
}

# ---------- Naming ----------

variable "project_name" {
  description = "Short project name used to build resource names (2-16 lowercase letters, numbers, hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,15}$", var.project_name))
    error_message = "project_name must be 2-16 lowercase letters, numbers or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment: dev, test, uat or prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "uat", "prod"], var.environment)
    error_message = "environment must be dev, test, uat or prod."
  }
}

variable "tags" {
  description = "Extra tags merged with the default tags."
  type        = map(string)
  default     = {}
}

# ---------- Services to deploy ----------

variable "deploy_app_service" {
  description = "Deploy a web app (settings in app_service)."
  type        = bool
  default     = false
}

variable "deploy_web_angular_api" {
  description = "Deploy an Angular client app and a .NET API app (settings in web_angular_api)."
  type        = bool
  default     = false
}

variable "deploy_function_app" {
  description = "Deploy an Azure Functions app on Flex Consumption (settings in function_app)."
  type        = bool
  default     = false
}

variable "deploy_storage_account" {
  description = "Deploy a storage account for application data (settings in storage_account)."
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Deploy Log Analytics + Application Insights, shared by all apps."
  type        = bool
  default     = true
}

# ---------- Service settings (all attributes optional) ----------

variable "app_service_plan" {
  description = "Shared Linux App Service Plan used by the web apps."
  type = object({
    sku_name       = optional(string, "B1")
    instance_count = optional(number, 1)
  })
  default = {}
}

variable "app_service" {
  description = "Web app settings."
  type = object({
    runtime_stack     = optional(string, "dotnet")
    runtime_version   = optional(string, "8.0")
    startup_command   = optional(string)
    health_check_path = optional(string)
    app_settings      = optional(map(string), {})
  })
  default = {}
}

variable "web_angular_api" {
  description = "Angular client + .NET API settings."
  type = object({
    client_node_version    = optional(string, "20-lts")
    client_app_settings    = optional(map(string), {})
    api_dotnet_version     = optional(string, "8.0")
    api_health_check_path  = optional(string)
    api_app_settings       = optional(map(string), {})
    api_extra_cors_origins = optional(list(string), [])
  })
  default = {}
}

variable "function_app" {
  description = "Function app settings."
  type = object({
    runtime_name           = optional(string, "dotnet-isolated")
    runtime_version        = optional(string, "8.0")
    instance_memory_mb     = optional(number, 2048)
    maximum_instance_count = optional(number, 100)
    app_settings           = optional(map(string), {})
    storage_authentication = optional(string, "ConnectionString")
  })
  default = {}
}

variable "storage_account" {
  description = "Data storage account settings."
  type = object({
    replication_type           = optional(string, "LRS")
    access_tier                = optional(string, "Hot")
    shared_access_key_enabled  = optional(bool, true)
    soft_delete_retention_days = optional(number, 7)
    versioning_enabled         = optional(bool, false)
    containers                 = optional(list(string), [])
    queues                     = optional(list(string), [])
    tables                     = optional(list(string), [])
    file_shares                = optional(list(string), [])
  })
  default = {}
}
