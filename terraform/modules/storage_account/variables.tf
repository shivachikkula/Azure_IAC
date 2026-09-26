variable "name" {
  description = "Globally unique storage account name (3-24 lowercase letters and numbers)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "name must be 3-24 lowercase letters and numbers."
  }
}

variable "location" {
  description = "Azure region for the account."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "tags" {
  description = "Tags applied to the account."
  type        = map(string)
  default     = {}
}

variable "account_tier" {
  description = "Standard or Premium."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "account_tier must be Standard or Premium."
  }
}

variable "replication_type" {
  description = "LRS (cheapest), ZRS, GRS, GZRS, RAGRS or RAGZRS."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type must be one of LRS, ZRS, GRS, GZRS, RAGRS, RAGZRS."
  }
}

variable "access_tier" {
  description = "Default blob access tier: Hot, Cool or Cold."
  type        = string
  default     = "Hot"

  validation {
    condition     = contains(["Hot", "Cool", "Cold"], var.access_tier)
    error_message = "access_tier must be Hot, Cool or Cold."
  }
}

variable "shared_access_key_enabled" {
  description = "Allow access with account keys / connection strings. false requires Microsoft Entra ID (managed identity) access."
  type        = bool
  default     = true
}

variable "public_network_access" {
  description = "Allow public (network) access. Set false when the account is only reached through private endpoints."
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Days to keep deleted blobs and containers (0 disables soft delete)."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 0 && var.soft_delete_retention_days <= 365
    error_message = "soft_delete_retention_days must be between 0 and 365."
  }
}

variable "versioning_enabled" {
  description = "Keep previous versions of blobs when they are overwritten or deleted."
  type        = bool
  default     = false
}

variable "containers" {
  description = "Blob container names to create (always private)."
  type        = list(string)
  default     = []
}

variable "queues" {
  description = "Queue names to create."
  type        = list(string)
  default     = []
}

variable "tables" {
  description = "Table names to create."
  type        = list(string)
  default     = []
}

variable "file_shares" {
  description = "File share names to create."
  type        = list(string)
  default     = []
}

variable "file_share_quota_gb" {
  description = "Quota in GB for each file share."
  type        = number
  default     = 100
}
