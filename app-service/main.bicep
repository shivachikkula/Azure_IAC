// Generic Azure App Service deployment.
// Creates (per app): an App Service Plan (or reuses an existing one), a Web App,
// and optionally Log Analytics + Application Insights and a staging slot.
//
// Deploy to an existing resource group:
//   az deployment group create -g <rg> -f main.bicep -p parameters/dev.bicepparam

targetScope = 'resourceGroup'

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

@description('Azure region. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Override the web app name (must be globally unique). Empty to auto-generate.')
param webAppName string = ''

@description('Extra tags merged with the default tags.')
param tags object = {}

// ---------- Hosting ----------

@description('Operating system for the App Service Plan.')
@allowed([
  'Linux'
  'Windows'
])
param osType string = 'Linux'

@description('App Service Plan SKU, e.g. F1, B1, S1, P0v3, P1v3.')
param skuName string = 'B1'

@description('Number of plan instances.')
@minValue(1)
@maxValue(30)
param instanceCount int = 1

@description('Zone-redundant plan (Premium v3, instanceCount >= 3).')
param zoneRedundant bool = false

@description('Resource ID of an existing App Service Plan to reuse. Empty to create a new plan.')
param existingAppServicePlanId string = ''

// ---------- Runtime ----------

@description('Runtime stack.')
@allowed([
  'dotnet'
  'node'
  'python'
  'java'
  'php'
])
param runtimeStack string = 'dotnet'

@description('Runtime version, e.g. dotnet "8.0", node "20-lts" (Linux) / "~20" (Windows), python "3.12", java "17-java17" (Linux) / "17" (Windows), php "8.3".')
param runtimeVersion string = '8.0'

@description('Startup command (Linux only).')
param startupCommand string = ''

@description('Health check path, e.g. /health. Empty to disable.')
param healthCheckPath string = ''

@description('App settings (environment variables) as key/value pairs. Do not put secrets here; use Key Vault references.')
param appSettings object = {}

// ---------- Features ----------

@description('Deploy Log Analytics + Application Insights and wire them to the app.')
param enableMonitoring bool = true

@description('Create a "staging" deployment slot (Standard tier or above).')
param createStagingSlot bool = false

@description('Subnet resource ID for outbound VNet integration. Empty to disable.')
param vnetSubnetId string = ''

// ---------- Validation ----------

var isFreeOrShared = startsWith(toUpper(skuName), 'F') || startsWith(toUpper(skuName), 'D')

// ---------- Names ----------

var namePrefix = toLower('${appName}-${environment}')
var planName = 'asp-${namePrefix}'
var generatedWebAppName = take('app-${namePrefix}-${uniqueString(resourceGroup().id, appName, environment)}', 60)
var finalWebAppName = empty(webAppName) ? generatedWebAppName : webAppName

var allTags = union({
  application: appName
  environment: environment
  managedBy: 'bicep'
}, tags)

// ---------- Resources ----------

module plan 'modules/appServicePlan.bicep' = if (empty(existingAppServicePlanId)) {
  name: '${deployment().name}-plan'
  params: {
    name: planName
    location: location
    tags: allTags
    osType: osType
    skuName: skuName
    capacity: instanceCount
    zoneRedundant: zoneRedundant
  }
}

module monitoring 'modules/monitoring.bicep' = if (enableMonitoring) {
  name: '${deployment().name}-monitoring'
  params: {
    namePrefix: namePrefix
    location: location
    tags: allTags
  }
}

module webApp 'modules/webApp.bicep' = {
  name: '${deployment().name}-webapp'
  params: {
    name: finalWebAppName
    location: location
    tags: allTags
    appServicePlanId: empty(existingAppServicePlanId) ? plan!.outputs.id : existingAppServicePlanId
    osType: osType
    runtimeStack: runtimeStack
    runtimeVersion: runtimeVersion
    alwaysOn: !isFreeOrShared
    healthCheckPath: healthCheckPath
    startupCommand: startupCommand
    appSettings: appSettings
    appInsightsConnectionString: enableMonitoring ? monitoring!.outputs.appInsightsConnectionString : ''
    vnetSubnetId: vnetSubnetId
    createStagingSlot: createStagingSlot
  }
}

// ---------- Outputs ----------

output webAppName string = webApp.outputs.name
output webAppUrl string = 'https://${webApp.outputs.defaultHostName}'
output webAppPrincipalId string = webApp.outputs.principalId
output stagingSlotUrl string = createStagingSlot ? 'https://${webApp.outputs.stagingSlotHostName}' : ''
output appServicePlanId string = empty(existingAppServicePlanId) ? plan!.outputs.id : existingAppServicePlanId
