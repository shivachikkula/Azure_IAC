using '../main.bicep'

// Resource group (created if it doesn't exist) and region for all resources
param resourceGroupName = 'rg-mywebapp-prod'
param location = 'westus2'

param appName = 'mywebapp'
param environment = 'prod'
param skuName = 'P0v3'
param instanceCount = 2
param clientNodeVersion = '20-lts'
param apiDotnetVersion = '8.0'
param apiHealthCheckPath = '/health'
param apiAppSettings = {
  ASPNETCORE_ENVIRONMENT: 'Production'
}
param apiExtraCorsOrigins = []
param enableMonitoring = true
param tags = {
  owner: 'shiva'
  costCenter: 'engineering'
  project: 'mywebapp'
}
