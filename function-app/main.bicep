// Generic Azure Functions deployment (Flex Consumption plan).
// Creates the resource group (name and location from the parameters file), a storage
// account for the Functions runtime and deployment package, a Flex Consumption plan,
// the function app, and optionally Log Analytics + Application Insights.
//
// Deploy (subscription scope):
//   az deployment sub create -l <location> -f main.bicep -p parameters/dev.bicepparam

targetScope = 'subscription'

// ---------- Resource group ----------

@description('Name of the resource group to create or update.')
@minLength(1)
@maxLength(90)
param resourceGroupName string

@description('Azure region for the resource group and all resources (must support Flex Consumption).')
param location string

// ---------- Naming ----------

@description('Short application name used to build resource names (letters, numbers, hyphens).')
@minLength(2)
@maxLength(16)
param appName string

@description('Deployment environment.')
@allowed([
  'dev'
  'test'
  'uat'
  'prod'
])
param environment string = 'dev'

@description('Override the function app name (globally unique). Empty to auto-generate.')
param functionAppName string = ''

@description('Extra tags merged with the default tags.')
param tags object = {}

// ---------- Runtime ----------

@description('Worker runtime.')
@allowed([
  'dotnet-isolated'
  'node'
  'python'
  'java'
  'powershell'
])
param runtimeName string = 'dotnet-isolated'

@description('Runtime version, e.g. dotnet-isolated "8.0", node "20", python "3.11", java "17", powershell "7.4".')
param runtimeVersion string = '8.0'

@description('Memory per instance in MB.')
@allowed([
  512
  2048
  4096
])
param instanceMemoryMB int = 2048

@description('Maximum number of instances the app can scale out to.')
param maximumInstanceCount int = 100

@description('App settings (environment variables). Do not put secrets here; use Key Vault references.')
param appSettings object = {}

// ---------- Features ----------

@description('How the app authenticates to its storage account. "ManagedIdentity" needs Owner or User Access Administrator on the deploying identity (it creates role assignments).')
@allowed([
  'ConnectionString'
  'ManagedIdentity'
])
param storageAuthentication string = 'ConnectionString'

@description('Deploy Log Analytics + Application Insights and wire them to the app.')
param enableMonitoring bool = true

// ---------- Names ----------

var namePrefix = toLower('${appName}-${environment}')
var suffix = uniqueString(subscription().id, resourceGroupName, appName, environment)
var generatedFunctionAppName = take('func-${namePrefix}-${suffix}', 60)
var finalFunctionAppName = empty(functionAppName) ? generatedFunctionAppName : functionAppName
var storageAccountName = take('stfn${toLower(replace(appName, '-', ''))}${suffix}', 24)
var deploymentContainerName = 'app-package'

var allTags = union({
  application: appName
  environment: environment
  managedBy: 'bicep'
}, tags)

// ---------- Resources ----------

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: allTags
}

module storage '../modules/storageAccount.bicep' = {
  name: '${deployment().name}-storage'
  scope: rg
  params: {
    name: storageAccountName
    location: location
    tags: allTags
    skuName: 'Standard_LRS'
    allowSharedKeyAccess: storageAuthentication == 'ConnectionString'
    containers: [
      deploymentContainerName
    ]
  }
}

module monitoring '../modules/monitoring.bicep' = if (enableMonitoring) {
  name: '${deployment().name}-monitoring'
  scope: rg
  params: {
    namePrefix: namePrefix
    location: location
    tags: allTags
  }
}

module functionApp '../modules/functionApp.bicep' = {
  name: '${deployment().name}-function'
  scope: rg
  params: {
    name: finalFunctionAppName
    planName: 'asp-${namePrefix}-func'
    location: location
    tags: allTags
    storageAccountName: storage.outputs.name
    deploymentContainerName: deploymentContainerName
    storageAuthentication: storageAuthentication
    runtimeName: runtimeName
    runtimeVersion: runtimeVersion
    instanceMemoryMB: instanceMemoryMB
    maximumInstanceCount: maximumInstanceCount
    appSettings: appSettings
    appInsightsConnectionString: enableMonitoring ? monitoring!.outputs.appInsightsConnectionString : ''
  }
}

// ---------- Outputs ----------

output resourceGroupName string = rg.name
output functionAppName string = functionApp.outputs.name
output functionAppUrl string = 'https://${functionApp.outputs.defaultHostName}'
output functionAppPrincipalId string = functionApp.outputs.principalId
output storageAccountName string = storage.outputs.name
