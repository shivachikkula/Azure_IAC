using '../main.bicep'

// Resource group (created if it doesn't exist) and region for all resources
param resourceGroupName = 'rg-myfunc-dev'
param location = 'westus2'

param appName = 'myfunc'
param environment = 'dev'
param runtimeName = 'dotnet-isolated'
param runtimeVersion = '8.0'
param instanceMemoryMB = 2048
param maximumInstanceCount = 40
param storageAuthentication = 'ConnectionString'
param enableMonitoring = true
param appSettings = {}
param tags = {
  owner: 'shiva'
  costCenter: 'engineering'
  project: 'myfunc'
}
