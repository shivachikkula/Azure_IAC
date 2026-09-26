// Project template: deploy only the services a project needs, into one resource group.
// Each project has a folder under projects/ with one parameters file per environment
// (e.g. projects/orders/dev.bicepparam) that switches services on with the deploy* flags.
//
//   deployAppService     - a web app (.NET, Node, Python, Java or PHP)
//   deployWebAngularApi  - an Angular client app + a .NET API app, CORS wired between them
//   deployFunctionApp    - Azure Functions on Flex Consumption, with its runtime storage account
//   deployStorageAccount - a storage account for application data
//
// The web apps share one Linux App Service Plan; the function app has its own Flex plan.
// Log Analytics + Application Insights are shared by all apps (enableMonitoring).
//
// Deploy (subscription scope):
//   az deployment sub create -l <location> -f projects/main.bicep -p projects/<project>/dev.bicepparam

targetScope = 'subscription'

// ---------- Resource group ----------

@description('Name of the resource group to create or update for this project.')
@minLength(1)
@maxLength(90)
param resourceGroupName string

@description('Azure region for all resources.')
param location string

@description('Region of the resource group itself. Empty means the same as location. Set it when the resource group already exists in a different region (a resource group cannot be moved).')
param resourceGroupLocation string = ''

// ---------- Naming ----------

@description('Short project name used to build resource names (letters, numbers, hyphens).')
@minLength(2)
@maxLength(16)
param projectName string

@description('Deployment environment.')
@allowed([
  'dev'
  'test'
  'uat'
  'prod'
])
param environment string = 'dev'

@description('Extra tags merged with the default tags.')
param tags object = {}

// ---------- Services to deploy ----------

@description('Deploy a web app (settings in appService).')
param deployAppService bool = false

@description('Deploy an Angular client app and a .NET API app (settings in webAngularApi).')
param deployWebAngularApi bool = false

@description('Deploy an Azure Functions app on Flex Consumption (settings in functionApp).')
param deployFunctionApp bool = false

@description('Deploy a storage account for application data (settings in storageAccount).')
param deployStorageAccount bool = false

@description('Deploy Log Analytics + Application Insights, shared by all apps.')
param enableMonitoring bool = true

// ---------- Service settings (all properties optional) ----------

@description('Shared Linux App Service Plan used by the web apps.')
type appServicePlanSettings = {
  @description('Plan SKU, e.g. F1, B1 (default), S1, P0v3.')
  skuName: string?

  @description('Number of plan instances (default 1).')
  instanceCount: int?
}

@description('Web app settings.')
type appServiceSettings = {
  @description('dotnet (default), node, python, java or php.')
  runtimeStack: string?

  @description('Runtime version, e.g. dotnet "8.0" (default), node "20-lts", python "3.12", java "17-java17", php "8.3".')
  runtimeVersion: string?

  @description('Custom startup command.')
  startupCommand: string?

  @description('Health check path, e.g. /health.')
  healthCheckPath: string?

  @description('App settings (environment variables).')
  appSettings: object?
}

@description('Angular client + .NET API settings.')
type webAngularApiSettings = {
  @description('Node version that serves the Angular build (default "20-lts").')
  clientNodeVersion: string?

  @description('App settings for the client app.')
  clientAppSettings: object?

  @description('.NET version for the API (default "8.0").')
  apiDotnetVersion: string?

  @description('Health check path for the API, e.g. /health.')
  apiHealthCheckPath: string?

  @description('App settings for the API.')
  apiAppSettings: object?

  @description('Extra origins allowed to call the API, e.g. http://localhost:4200. The client app URL is always allowed.')
  apiExtraCorsOrigins: string[]?
}

@description('Function app settings.')
type functionAppSettings = {
  @description('dotnet-isolated (default), node, python, java or powershell.')
  runtimeName: string?

  @description('Runtime version, e.g. dotnet-isolated "8.0" (default), node "20", python "3.11", java "17", powershell "7.4".')
  runtimeVersion: string?

  @description('Memory per instance: 512, 2048 (default) or 4096.')
  instanceMemoryMB: int?

  @description('Scale-out limit, 40-1000 (default 100).')
  maximumInstanceCount: int?

  @description('App settings (environment variables).')
  appSettings: object?

  @description('ConnectionString (default) or ManagedIdentity (needs Owner or User Access Administrator on the deploying identity).')
  storageAuthentication: string?
}

@description('Data storage account settings.')
type storageAccountSettings = {
  @description('Replication SKU, e.g. Standard_LRS (default), Standard_ZRS, Standard_GRS.')
  skuName: string?

  @description('Hot (default), Cool or Cold.')
  accessTier: string?

  @description('Allow account keys / connection strings (default true).')
  allowSharedKeyAccess: bool?

  @description('Days to keep deleted blobs and containers (default 7, 0 disables).')
  softDeleteRetentionDays: int?

  @description('Keep previous blob versions (default false).')
  enableVersioning: bool?

  @description('Blob container names.')
  containers: string[]?

  @description('Queue names.')
  queues: string[]?

  @description('Table names.')
  tables: string[]?

  @description('File share names.')
  fileShares: string[]?
}

param appServicePlan appServicePlanSettings = {}
param appService appServiceSettings = {}
param webAngularApi webAngularApiSettings = {}
param functionApp functionAppSettings = {}
param storageAccount storageAccountSettings = {}

// ---------- Names ----------

var namePrefix = toLower('${projectName}-${environment}')
var compactName = toLower(replace(projectName, '-', ''))
var suffix = uniqueString(subscription().id, resourceGroupName, projectName, environment)

var needsPlan = deployAppService || deployWebAngularApi
var needsMonitoring = enableMonitoring && (deployAppService || deployWebAngularApi || deployFunctionApp)

var planSku = appServicePlan.?skuName ?? 'B1'
var isFreeOrShared = startsWith(toUpper(planSku), 'F') || startsWith(toUpper(planSku), 'D')

var allTags = union({
  application: projectName
  environment: environment
  managedBy: 'bicep'
}, tags)

// ---------- Shared resources ----------

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: empty(resourceGroupLocation) ? location : resourceGroupLocation
  tags: allTags
}

module plan '../modules/appServicePlan.bicep' = if (needsPlan) {
  name: '${deployment().name}-plan'
  scope: rg
  params: {
    name: 'asp-${namePrefix}'
    location: location
    tags: allTags
    osType: 'Linux'
    skuName: planSku
    capacity: appServicePlan.?instanceCount ?? 1
  }
}

module monitoring '../modules/monitoring.bicep' = if (needsMonitoring) {
  name: '${deployment().name}-monitoring'
  scope: rg
  params: {
    namePrefix: namePrefix
    location: location
    tags: allTags
  }
}

var appInsightsConnectionString = needsMonitoring ? monitoring!.outputs.appInsightsConnectionString : ''

// ---------- App Service ----------

module webApp '../modules/webApp.bicep' = if (deployAppService) {
  name: '${deployment().name}-webapp'
  scope: rg
  params: {
    name: take('app-${namePrefix}-${suffix}', 60)
    location: location
    tags: allTags
    appServicePlanId: plan!.outputs.id
    osType: 'Linux'
    runtimeStack: appService.?runtimeStack ?? 'dotnet'
    runtimeVersion: appService.?runtimeVersion ?? '8.0'
    startupCommand: appService.?startupCommand ?? ''
    healthCheckPath: appService.?healthCheckPath ?? ''
    appSettings: appService.?appSettings ?? {}
    alwaysOn: !isFreeOrShared
    appInsightsConnectionString: appInsightsConnectionString
  }
}

// ---------- Angular client + .NET API ----------

module clientApp '../modules/webApp.bicep' = if (deployWebAngularApi) {
  name: '${deployment().name}-client'
  scope: rg
  params: {
    name: take('app-${namePrefix}-web-${suffix}', 60)
    location: location
    tags: allTags
    appServicePlanId: plan!.outputs.id
    osType: 'Linux'
    runtimeStack: 'node'
    runtimeVersion: webAngularApi.?clientNodeVersion ?? '20-lts'
    // Serve the static Angular build and fall back to index.html for client-side routes
    startupCommand: 'pm2 serve /home/site/wwwroot --no-daemon --spa'
    appSettings: webAngularApi.?clientAppSettings ?? {}
    alwaysOn: !isFreeOrShared
    appInsightsConnectionString: appInsightsConnectionString
  }
}

module apiApp '../modules/webApp.bicep' = if (deployWebAngularApi) {
  name: '${deployment().name}-api'
  scope: rg
  params: {
    name: take('app-${namePrefix}-api-${suffix}', 60)
    location: location
    tags: allTags
    appServicePlanId: plan!.outputs.id
    osType: 'Linux'
    runtimeStack: 'dotnet'
    runtimeVersion: webAngularApi.?apiDotnetVersion ?? '8.0'
    healthCheckPath: webAngularApi.?apiHealthCheckPath ?? ''
    appSettings: webAngularApi.?apiAppSettings ?? {}
    alwaysOn: !isFreeOrShared
    appInsightsConnectionString: appInsightsConnectionString
    corsAllowedOrigins: union([
      'https://${clientApp!.outputs.defaultHostName}'
    ], webAngularApi.?apiExtraCorsOrigins ?? [])
  }
}

// ---------- Function App ----------

var functionStorageAuthentication = functionApp.?storageAuthentication ?? 'ConnectionString'

module functionStorage '../modules/storageAccount.bicep' = if (deployFunctionApp) {
  name: '${deployment().name}-funcstorage'
  scope: rg
  params: {
    name: take('stfn${compactName}${suffix}', 24)
    location: location
    tags: allTags
    skuName: 'Standard_LRS'
    allowSharedKeyAccess: functionStorageAuthentication == 'ConnectionString'
    containers: [
      'app-package'
    ]
  }
}

module funcApp '../modules/functionApp.bicep' = if (deployFunctionApp) {
  name: '${deployment().name}-function'
  scope: rg
  params: {
    name: take('func-${namePrefix}-${suffix}', 60)
    planName: 'asp-${namePrefix}-func'
    location: location
    tags: allTags
    storageAccountName: functionStorage!.outputs.name
    deploymentContainerName: 'app-package'
    storageAuthentication: functionStorageAuthentication
    runtimeName: functionApp.?runtimeName ?? 'dotnet-isolated'
    runtimeVersion: functionApp.?runtimeVersion ?? '8.0'
    instanceMemoryMB: functionApp.?instanceMemoryMB ?? 2048
    maximumInstanceCount: functionApp.?maximumInstanceCount ?? 100
    appSettings: functionApp.?appSettings ?? {}
    appInsightsConnectionString: appInsightsConnectionString
  }
}

// ---------- Storage account ----------

module dataStorage '../modules/storageAccount.bicep' = if (deployStorageAccount) {
  name: '${deployment().name}-storage'
  scope: rg
  params: {
    name: take('st${compactName}${environment}${suffix}', 24)
    location: location
    tags: allTags
    skuName: storageAccount.?skuName ?? 'Standard_LRS'
    accessTier: storageAccount.?accessTier ?? 'Hot'
    allowSharedKeyAccess: storageAccount.?allowSharedKeyAccess ?? true
    softDeleteRetentionDays: storageAccount.?softDeleteRetentionDays ?? 7
    enableVersioning: storageAccount.?enableVersioning ?? false
    containers: storageAccount.?containers ?? []
    queues: storageAccount.?queues ?? []
    tables: storageAccount.?tables ?? []
    fileShares: storageAccount.?fileShares ?? []
  }
}

// ---------- Outputs (empty for services that are switched off) ----------

output resourceGroupName string = rg.name
output appServiceName string = deployAppService ? webApp!.outputs.name : ''
output appServiceUrl string = deployAppService ? 'https://${webApp!.outputs.defaultHostName}' : ''
output clientAppName string = deployWebAngularApi ? clientApp!.outputs.name : ''
output clientUrl string = deployWebAngularApi ? 'https://${clientApp!.outputs.defaultHostName}' : ''
output apiAppName string = deployWebAngularApi ? apiApp!.outputs.name : ''
output apiUrl string = deployWebAngularApi ? 'https://${apiApp!.outputs.defaultHostName}' : ''
output functionAppName string = deployFunctionApp ? funcApp!.outputs.name : ''
output functionAppUrl string = deployFunctionApp ? 'https://${funcApp!.outputs.defaultHostName}' : ''
output storageAccountName string = deployStorageAccount ? dataStorage!.outputs.name : ''
