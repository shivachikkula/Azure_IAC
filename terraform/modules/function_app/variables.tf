variable "name" {
  description = "Globally unique name of the function app."
  type        = string
}

variable "plan_name" {
  description = "Name of the Flex Consumption plan to create."
  type        = string
}

variable "location" {
  description = "Azure region for the plan and app."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "tags" {
  description = "Tags applied to the plan and app."
  type        = map(string)
  default     = {}
}

variable "storage_account_id" {
  description = "ID of the storage account used by the Functions runtime."
  type        = string
}

variable "storage_account_name" {
  description = "Name of that storage account."
  type        = string
}

variable "storage_primary_blob_endpoint" {
  description = "Primary blob endpoint of that storage account (ends with /)."
  type        = string
}

variable "storage_access_key" {
  description = "Access key of that storage account; used when storage_authentication is ConnectionString."
  type        = string
  default     = null
  sensitive   = true
}

variable "storage_authentication" {
  description = "ConnectionString, or ManagedIdentity (creates role assignments, so needs Owner or User Access Administrator on the deploying identity)."
  type        = string
  default     = "ConnectionString"

  validation {
    condition     = contains(["ConnectionString", "ManagedIdentity"], var.storage_authentication)
    error_message = "storage_authentication must be ConnectionString or ManagedIdentity."
  }
}

variable "runtime_name" {
  description = "Worker runtime: dotnet-isolated, node, python, java or powershell."
  type        = string

  validation {
    condition     = contains(["dotnet-isolated", "node", "python", "java", "powershell"], var.runtime_name)
    error_message = "runtime_name must be dotnet-isolated, node, python, java or powershell."
  }
}

variable "runtime_version" {
  description = "Runtime version, e.g. dotnet-isolated \"8.0\", node \"20\", python \"3.11\", java \"17\", powershell \"7.4\"."
  type        = string
}

variable "instance_memory_mb" {
  description = "Memory per instance in MB: 512, 2048 or 4096."
  type        = number
  default     = 2048

  validation {
    condition     = contains([512, 2048, 4096], var.instance_memory_mb)
    error_message = "instance_memory_mb must be 512, 2048 or 4096."
  }
}

variable "maximum_instance_count" {
  description = "Maximum number of instances (40-1000)."
  type        = number
  default     = 100

  validation {
    condition     = var.maximum_instance_count >= 40 && var.maximum_instance_count <= 1000
    error_message = "maximum_instance_count must be between 40 and 1000."
  }
}

variable "app_settings" {
  description = "App settings (environment variables). Don't set FUNCTIONS_WORKER_RUNTIME or FUNCTIONS_EXTENSION_VERSION on Flex Consumption."
  type        = map(string)
  default     = {}
}

variable "app_insights_connection_string" {
  description = "Application Insights connection string. null to skip."
  type        = string
  default     = null
  sensitive   = true
}
