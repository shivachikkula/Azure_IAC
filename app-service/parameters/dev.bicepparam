using '../main.bicep'

// Resource group (created if it doesn't exist) and region for all resources
param resourceGroupName = 'rg-myapp-dev'
param location = 'westus2' // eastus has no App Service quota on this subscription

param appName = 'myapp'
param environment = 'dev'
param osType = 'Linux'
param skuName = 'F1' // Free tier: no Always On, slots or VNet integration; use B1+ once quota allows
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
