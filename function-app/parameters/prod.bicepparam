using '../main.bicep'

// Resource group (created if it doesn't exist) and region for all resources
param resourceGroupName = 'rg-myfunc-prod'
param location = 'westus2'

param appName = 'myfunc'
param environment = 'prod'
param runtimeName = 'dotnet-isolated'
param runtimeVersion = '8.0'
param instanceMemoryMB = 2048
param maximumInstanceCount = 100
// 'ManagedIdentity' avoids storage keys but needs Owner or User Access Administrator on the deploying identity
param storageAuthentication = 'ConnectionString'
param enableMonitoring = true
param appSettings = {}
param tags = {
  owner: 'shiva'
  costCenter: 'engineering'
  project: 'myfunc'
}
