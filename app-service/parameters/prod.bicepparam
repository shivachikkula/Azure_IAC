using '../main.bicep'

// Resource group (created if it doesn't exist) and region for all resources
param resourceGroupName = 'rg-myapp-prod'
param location = 'eastus'

param appName = 'myapp'
param environment = 'prod'
param osType = 'Linux'
param skuName = 'P1v3'
param instanceCount = 3
param zoneRedundant = true
param runtimeStack = 'dotnet'
param runtimeVersion = '8.0'
param healthCheckPath = '/health'
param enableMonitoring = true
param createStagingSlot = true
param appSettings = {
  ASPNETCORE_ENVIRONMENT: 'Production'
}
param tags = {
  owner: 'team-name'
  costCenter: '0000'
}
