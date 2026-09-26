variable "name" {
  description = "Globally unique name of the web app."
  type        = string
}

variable "location" {
  description = "Azure region for the app."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "tags" {
  description = "Tags applied to the app."
  type        = map(string)
  default     = {}
}

variable "service_plan_id" {
  description = "ID of the Linux App Service Plan that hosts the app."
  type        = string
}

variable "runtime_stack" {
  description = "Runtime stack: dotnet, node, python, java or php."
  type        = string

  validation {
    condition     = contains(["dotnet", "node", "python", "java", "php"], var.runtime_stack)
    error_message = "runtime_stack must be dotnet, node, python, java or php."
  }
}

variable "runtime_version" {
  description = "Runtime version, e.g. dotnet \"8.0\", node \"20-lts\", python \"3.12\", java \"17\", php \"8.3\"."
  type        = string
}

variable "always_on" {
  description = "Keep the app loaded when idle. Not supported on Free/Shared tiers."
  type        = bool
  default     = true
}

variable "startup_command" {
  description = "Custom startup command. null for the platform default."
  type        = string
  default     = null
}

variable "health_check_path" {
  description = "Health check path, e.g. /health. null to disable."
  type        = string
  default     = null
}

variable "app_settings" {
  description = "App settings (environment variables)."
  type        = map(string)
  default     = {}
}

variable "app_insights_connection_string" {
  description = "Application Insights connection string. null to skip monitoring settings."
  type        = string
  default     = null
  sensitive   = true
}

variable "cors_allowed_origins" {
  description = "Origins allowed to call the app from a browser (CORS). Empty to leave CORS unset."
  type        = list(string)
  default     = []
}

variable "vnet_subnet_id" {
  description = "Subnet ID (delegated to Microsoft.Web/serverFarms) for outbound VNet integration. null to disable."
  type        = string
  default     = null
}
