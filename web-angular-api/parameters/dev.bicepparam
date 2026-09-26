using '../main.bicep'

// Resource group (created if it doesn't exist) and region for all resources
param resourceGroupName = 'rg-mywebapp-dev'
param location = 'westus2'

param appName = 'mywebapp'
param environment = 'dev'
param skuName = 'F1' // Free tier: both apps share one plan; no Always On
param instanceCount = 1
param clientNodeVersion = '20-lts'
param apiDotnetVersion = '8.0'
param apiHealthCheckPath = ''
param apiAppSettings = {
  ASPNETCORE_ENVIRONMENT: 'Development'
}
param apiExtraCorsOrigins = [
  'http://localhost:4200' // Angular dev server (ng serve) calling the dev API
]
param enableMonitoring = true
param tags = {
  owner: 'shiva'
  costCenter: 'engineering'
  project: 'mywebapp'
}
