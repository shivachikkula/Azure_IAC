# Storage account (StorageV2) with secure defaults, plus optional blob containers,
# queues, tables and file shares.

resource "azurerm_storage_account" "this" {
  name                             = var.name
  location                         = var.location
  resource_group_name              = var.resource_group_name
  account_kind                     = "StorageV2"
  account_tier                     = var.account_tier
  account_replication_type         = var.replication_type
  access_tier                      = var.access_tier
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  shared_access_key_enabled        = var.shared_access_key_enabled
  default_to_oauth_authentication  = !var.shared_access_key_enabled
  public_network_access            = var.public_network_access ? "Enabled" : "Disabled"
  tags                             = var.tags

  blob_properties {
    versioning_enabled = var.versioning_enabled

    dynamic "delete_retention_policy" {
      for_each = var.soft_delete_retention_days > 0 ? [1] : []
      content {
        days = var.soft_delete_retention_days
      }
    }

    dynamic "container_delete_retention_policy" {
      for_each = var.soft_delete_retention_days > 0 ? [1] : []
      content {
        days = var.soft_delete_retention_days
      }
    }
  }
}

resource "azurerm_storage_container" "this" {
  for_each              = toset(var.containers)
  name                  = each.value
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_queue" "this" {
  for_each           = toset(var.queues)
  name               = each.value
  storage_account_id = azurerm_storage_account.this.id
}

resource "azurerm_storage_table" "this" {
  for_each           = toset(var.tables)
  name               = each.value
  storage_account_id = azurerm_storage_account.this.id
}

resource "azurerm_storage_share" "this" {
  for_each           = toset(var.file_shares)
  name               = each.value
  storage_account_id = azurerm_storage_account.this.id
  quota              = var.file_share_quota_gb
}
