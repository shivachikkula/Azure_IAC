using '../main.bicep'

// Resource group (created if it doesn't exist) and region for all resources
param resourceGroupName = 'rg-myapp-dev'
param location = 'eastus'

param appName = 'myapp'
param environment = 'dev'
param osType = 'Linux'
param skuName = 'B1'
param instanceCount = 1
param runtimeStack = 'dotnet'
param runtimeVersion = '8.0'
param healthCheckPath = ''
param enableMonitoring = true
param createStagingSlot = false
param appSettings = {
  ASPNETCORE_ENVIRONMENT: 'Development'
}
param tags = {
  owner: 'team-name'
  costCenter: '0000'
}
