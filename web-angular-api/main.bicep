// Angular client + .NET API on Azure App Service.
// Creates the resource group (name and location from the parameters file), one Linux
// App Service Plan shared by two web apps, and optionally Log Analytics + Application Insights:
//   - client: serves the built Angular app (dist output) as a single-page app via pm2
//   - api:    ASP.NET Core API, with CORS allowing the client's URL
//
// Deploy (subscription scope):
//   az deployment sub create -l <location> -f main.bicep -p parameters/dev.bicepparam

targetScope = 'subscription'

// ---------- Resource group ----------

@description('Name of the resource group to create or update.')
@minLength(1)
@maxLength(90)
param resourceGroupName string

@description('Azure region for the resource group and all resources.')
param location string

@description('Region of the resource group itself. Empty means the same as location. Set it when the resource group already exists in a different region (a resource group cannot be moved).')
param resourceGroupLocation string = ''

// ---------- Naming ----------

@description('Short application name used to build resource names (letters, numbers, hyphens).')
@minLength(2)
@maxLength(20)
param appName string

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

// ---------- Hosting ----------

@description('App Service Plan SKU shared by both apps, e.g. F1, B1, S1, P0v3.')
param skuName string = 'B1'

@description('Number of plan instances.')
@minValue(1)
@maxValue(30)
param instanceCount int = 1

@description('Resource ID of an existing Linux App Service Plan to reuse. Empty to create a new plan.')
param existingAppServicePlanId string = ''

// ---------- Client (Angular) ----------

@description('Node.js version used to serve the Angular build, e.g. "20-lts", "22-lts".')
param clientNodeVersion string = '20-lts'

@description('App settings for the client app.')
param clientAppSettings object = {}

// ---------- API (.NET) ----------

@description('.NET version for the API, e.g. "8.0", "9.0".')
param apiDotnetVersion string = '8.0'

@description('Health check path for the API, e.g. /health. Empty to disable.')
param apiHealthCheckPath string = ''

@description('App settings for the API (e.g. ASPNETCORE_ENVIRONMENT). Do not put secrets here; use Key Vault references.')
param apiAppSettings object = {}

@description('Extra origins allowed to call the API (e.g. a custom domain or http://localhost:4200). The client app URL is always allowed.')
param apiExtraCorsOrigins array = []

// ---------- Features ----------

@description('Deploy Log Analytics + Application Insights and wire them to both apps.')
param enableMonitoring bool = true

// ---------- Names ----------

var isFreeOrShared = startsWith(toUpper(skuName), 'F') || startsWith(toUpper(skuName), 'D')
var namePrefix = toLower('${appName}-${environment}')
var suffix = uniqueString(subscription().id, resourceGroupName, appName, environment)
var clientAppName = take('app-${namePrefix}-web-${suffix}', 60)
var apiAppName = take('app-${namePrefix}-api-${suffix}', 60)

var allTags = union({
  application: appName
  environment: environment
  managedBy: 'bicep'
}, tags)

// ---------- Resources ----------

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: empty(resourceGroupLocation) ? location : resourceGroupLocation
  tags: allTags
}

module plan '../modules/appServicePlan.bicep' = if (empty(existingAppServicePlanId)) {
  name: '${deployment().name}-plan'
  scope: rg
  params: {
    name: 'asp-${namePrefix}'
    location: location
    tags: allTags
    osType: 'Linux'
    skuName: skuName
    capacity: instanceCount
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

var planId = empty(existingAppServicePlanId) ? plan!.outputs.id : existingAppServicePlanId
var appInsightsConnectionString = enableMonitoring ? monitoring!.outputs.appInsightsConnectionString : ''

module clientApp '../modules/webApp.bicep' = {
  name: '${deployment().name}-client'
  scope: rg
  params: {
    name: clientAppName
    location: location
    tags: allTags
    appServicePlanId: planId
    osType: 'Linux'
    runtimeStack: 'node'
    runtimeVersion: clientNodeVersion
    // Serve the static Angular build and fall back to index.html for client-side routes
    startupCommand: 'pm2 serve /home/site/wwwroot --no-daemon --spa'
    alwaysOn: !isFreeOrShared
    appSettings: clientAppSettings
    appInsightsConnectionString: appInsightsConnectionString
  }
}

module apiApp '../modules/webApp.bicep' = {
  name: '${deployment().name}-api'
  scope: rg
  params: {
    name: apiAppName
    location: location
    tags: allTags
    appServicePlanId: planId
    osType: 'Linux'
    runtimeStack: 'dotnet'
    runtimeVersion: apiDotnetVersion
    alwaysOn: !isFreeOrShared
    healthCheckPath: apiHealthCheckPath
    appSettings: apiAppSettings
    appInsightsConnectionString: appInsightsConnectionString
    corsAllowedOrigins: union([
      'https://${clientApp.outputs.defaultHostName}'
    ], apiExtraCorsOrigins)
  }
}

// ---------- Outputs ----------

output resourceGroupName string = rg.name
output clientAppName string = clientApp.outputs.name
output clientUrl string = 'https://${clientApp.outputs.defaultHostName}'
output apiAppName string = apiApp.outputs.name
output apiUrl string = 'https://${apiApp.outputs.defaultHostName}'
output apiPrincipalId string = apiApp.outputs.principalId
