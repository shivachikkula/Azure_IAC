// Example project. Copy this folder to projects/<your-project>/, then switch on the
// services you need. Folders starting with "_" are validated but never deployed.
using '../main.bicep'

// Resource group (created if it doesn't exist) and region for all resources
param resourceGroupName = 'rg-example-dev'
param location = 'westus2'
// param resourceGroupLocation = 'eastus' // only if the resource group already exists in another region

param projectName = 'example'
param environment = 'dev'
param tags = {
  owner: 'your-name'
  costCenter: 'your-cost-center'
}

// ---------- Services: switch on only what you need ----------
param deployAppService = false
param deployWebAngularApi = true
param deployFunctionApp = true
param deployStorageAccount = true
param enableMonitoring = true

// ---------- Settings (every property is optional; defaults shown) ----------

// Shared Linux plan for the web apps (App Service, Angular client, .NET API)
param appServicePlan = {
  skuName: 'F1' // cheapest; B1 (default) or higher for Always On and production use
  instanceCount: 1
}

param appService = {
  runtimeStack: 'dotnet' // dotnet, node, python, java, php
  runtimeVersion: '8.0'
  healthCheckPath: ''
  appSettings: {}
}

param webAngularApi = {
  clientNodeVersion: '20-lts'
  apiDotnetVersion: '8.0'
  apiHealthCheckPath: ''
  apiAppSettings: {
    ASPNETCORE_ENVIRONMENT: 'Development'
  }
  apiExtraCorsOrigins: [
    'http://localhost:4200' // Angular dev server calling the dev API
  ]
}

param functionApp = {
  runtimeName: 'dotnet-isolated' // dotnet-isolated, node, python, java, powershell
  runtimeVersion: '8.0'
  instanceMemoryMB: 2048
  maximumInstanceCount: 40
  appSettings: {}
}

param storageAccount = {
  skuName: 'Standard_LRS'
  containers: [
    'uploads'
  ]
  queues: []
  tables: []
}
