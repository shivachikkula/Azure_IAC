using '../main.bicep'

// Resource group (created if it doesn't exist) and region for all resources
param resourceGroupName = 'rg-mystorage-dev'
param location = 'westus2'

param appName = 'mystorage'
param environment = 'dev'
param skuName = 'Standard_LRS'
param accessTier = 'Hot'
param softDeleteRetentionDays = 7
param enableVersioning = false
param containers = [
  'uploads'
]
param queues = []
param tables = []
param fileShares = []
param tags = {
  owner: 'shiva'
  costCenter: 'engineering'
  project: 'mystorage'
}
