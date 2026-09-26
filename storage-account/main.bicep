// Generic Azure Storage account deployment.
// Creates the resource group (name and location from the parameters file) and a
// StorageV2 account with secure defaults, plus optional containers, queues, tables and file shares.
//
// Deploy (subscription scope):
//   az deployment sub create -l <location> -f main.bicep -p parameters/dev.bicepparam

targetScope = 'subscription'

// ---------- Resource group ----------

@description('Name of the resource group to create or update.')
@minLength(1)
@maxLength(90)
param resourceGroupName string

@description('Azure region for the resource group and all resources.')
param location string

@description('Region of the resource group itself. Empty means the same as location. Set it when the resource group already exists in a different region (a resource group cannot be moved).')
param resourceGroupLocation string = ''

// ---------- Naming ----------

@description('Short application name used to build the account name (letters and numbers).')
@minLength(2)
@maxLength(10)
param appName string

@description('Deployment environment.')
@allowed([
  'dev'
  'test'
  'uat'
  'prod'
])
param environment string = 'dev'

@description('Override the storage account name (3-24 lowercase letters/numbers, globally unique). Empty to auto-generate.')
param storageAccountName string = ''

@description('Extra tags merged with the default tags.')
param tags object = {}

// ---------- Storage ----------

@description('Replication SKU, e.g. Standard_LRS (cheapest), Standard_ZRS, Standard_GRS.')
param skuName string = 'Standard_LRS'

@description('Default access tier for blobs.')
@allowed([
  'Hot'
  'Cool'
  'Cold'
])
param accessTier string = 'Hot'

@description('Allow access with account keys / connection strings. Set false to require Microsoft Entra ID only.')
param allowSharedKeyAccess bool = true

@description('Allow public (network) access.')
param publicNetworkAccess bool = true

@description('Days to keep deleted blobs and containers (0 to disable).')
param softDeleteRetentionDays int = 7

@description('Keep previous versions of overwritten or deleted blobs.')
param enableVersioning bool = false

@description('Blob container names to create (always private).')
param containers array = []

@description('Queue names to create.')
param queues array = []

@description('Table names to create.')
param tables array = []

@description('File share names to create.')
param fileShares array = []

// ---------- Names ----------

var generatedName = take('st${toLower(replace(appName, '-', ''))}${environment}${uniqueString(subscription().id, resourceGroupName, appName, environment)}', 24)
var finalName = empty(storageAccountName) ? generatedName : storageAccountName

var allTags = union({
  application: appName
  environment: environment
  managedBy: 'bicep'
}, tags)

// ---------- Resources ----------

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: empty(resourceGroupLocation) ? location : resourceGroupLocation
  tags: allTags
}

module storage '../modules/storageAccount.bicep' = {
  name: '${deployment().name}-storage'
  scope: rg
  params: {
    name: finalName
    location: location
    tags: allTags
    skuName: skuName
    accessTier: accessTier
    allowSharedKeyAccess: allowSharedKeyAccess
    publicNetworkAccess: publicNetworkAccess
    softDeleteRetentionDays: softDeleteRetentionDays
    enableVersioning: enableVersioning
    containers: containers
    queues: queues
    tables: tables
    fileShares: fileShares
  }
}

// ---------- Outputs ----------

output resourceGroupName string = rg.name
output storageAccountName string = storage.outputs.name
output storageAccountId string = storage.outputs.id
output blobEndpoint string = storage.outputs.primaryEndpoints.blob
