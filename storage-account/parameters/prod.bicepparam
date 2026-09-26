using '../main.bicep'

// Resource group (created if it doesn't exist) and region for all resources
param resourceGroupName = 'rg-mystorage-prod'
param location = 'westus2'

param appName = 'mystorage'
param environment = 'prod'
param skuName = 'Standard_ZRS'
param accessTier = 'Hot'
param softDeleteRetentionDays = 30
param enableVersioning = true
param containers = [
  'uploads'
]
param tags = {
  owner: 'shiva'
  costCenter: 'engineering'
  project: 'mystorage'
}
