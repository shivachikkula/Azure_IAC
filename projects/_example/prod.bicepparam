// Example production settings for the same project. Merging a change to a prod file
// deploys to the "prod" GitHub environment (add required reviewers there for approval).
using '../main.bicep'

param resourceGroupName = 'rg-example-prod'
param location = 'westus2'

param projectName = 'example'
param environment = 'prod'
param tags = {
  owner: 'your-name'
  costCenter: 'your-cost-center'
}

param deployAppService = false
param deployWebAngularApi = true
param deployFunctionApp = true
param deployStorageAccount = true
param enableMonitoring = true

param appServicePlan = {
  skuName: 'P0v3'
  instanceCount: 2
}

param webAngularApi = {
  apiDotnetVersion: '8.0'
  apiHealthCheckPath: '/health'
  apiAppSettings: {
    ASPNETCORE_ENVIRONMENT: 'Production'
  }
}

param functionApp = {
  runtimeName: 'dotnet-isolated'
  runtimeVersion: '8.0'
  maximumInstanceCount: 100
}

param storageAccount = {
  skuName: 'Standard_ZRS'
  softDeleteRetentionDays: 30
  enableVersioning: true
  containers: [
    'uploads'
  ]
}
