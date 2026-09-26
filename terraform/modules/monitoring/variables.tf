variable "name_prefix" {
  description = "Base name used to derive resource names, e.g. orders-dev."
  type        = string
}

variable "location" {
  description = "Azure region for the resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "retention_in_days" {
  description = "Log Analytics data retention in days."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}
