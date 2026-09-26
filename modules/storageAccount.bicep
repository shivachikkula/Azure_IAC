// Storage account (StorageV2) with secure defaults, plus optional blob containers,
// queues, tables and file shares.

@description('Globally unique storage account name (3-24 lowercase letters and numbers).')
@minLength(3)
@maxLength(24)
param name string

@description('Azure region for the account.')
param location string

@description('Tags applied to the account.')
param tags object = {}

@description('Replication SKU.')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Premium_LRS'
  'Premium_ZRS'
])
param skuName string = 'Standard_LRS'

@description('Default access tier for blobs.')
@allowed([
  'Hot'
  'Cool'
  'Cold'
])
param accessTier string = 'Hot'

@description('Allow access with account keys / connection strings. Set false to require Microsoft Entra ID (managed identity) access only.')
param allowSharedKeyAccess bool = true

@description('Allow public (network) access. Set false when the account is only reached through private endpoints.')
param publicNetworkAccess bool = true

@description('Days to keep deleted blobs and containers (0 to disable soft delete).')
@minValue(0)
@maxValue(365)
param softDeleteRetentionDays int = 7

@description('Keep previous versions of blobs when they are overwritten or deleted.')
param enableVersioning bool = false

@description('Blob container names to create. Containers are always private.')
param containers array = []

@description('Queue names to create.')
param queues array = []

@description('Table names to create.')
param tables array = []

@description('File share names to create (5 TiB quota each unless the account is Premium).')
param fileShares array = []

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    accessTier: accessTier
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication: !allowSharedKeyAccess
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: publicNetworkAccess ? 'Allow' : 'Deny'
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    isVersioningEnabled: enableVersioning
    deleteRetentionPolicy: {
      enabled: softDeleteRetentionDays > 0
      days: softDeleteRetentionDays > 0 ? softDeleteRetentionDays : null
    }
    containerDeleteRetentionPolicy: {
      enabled: softDeleteRetentionDays > 0
      days: softDeleteRetentionDays > 0 ? softDeleteRetentionDays : null
    }
  }
}

resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for container in containers: {
  parent: blobService
  name: container
  properties: {
    publicAccess: 'None'
  }
}]

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = if (!empty(queues)) {
  parent: storage
  name: 'default'
}

resource storageQueues 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-05-01' = [for queue in queues: {
  parent: queueService
  name: queue
}]

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = if (!empty(tables)) {
  parent: storage
  name: 'default'
}

resource storageTables 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01' = [for table in tables: {
  parent: tableService
  name: table
}]

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = if (!empty(fileShares)) {
  parent: storage
  name: 'default'
}

resource shares 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = [for share in fileShares: {
  parent: fileService
  name: share
}]

output id string = storage.id
output name string = storage.name
output primaryEndpoints object = storage.properties.primaryEndpoints
