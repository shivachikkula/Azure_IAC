// Web App (App Service) with optional staging slot and VNet integration.

@description('Globally unique name of the web app.')
param name string

@description('Azure region for the app.')
param location string

@description('Tags applied to the app.')
param tags object = {}

@description('Resource ID of the App Service Plan that hosts the app.')
param appServicePlanId string

@description('Operating system of the hosting plan.')
@allowed([
  'Linux'
  'Windows'
])
param osType string

@description('Runtime stack.')
@allowed([
  'dotnet'
  'node'
  'python'
  'java'
  'php'
])
param runtimeStack string

@description('Runtime version, e.g. dotnet "8.0", node "20-lts" (Linux) / "~20" (Windows), python "3.12", java "17-java17" (Linux) / "17" (Windows), php "8.3".')
param runtimeVersion string

@description('Keep the app loaded when idle. Not supported on Free/Shared tiers.')
param alwaysOn bool = true

@description('Minimum TLS version.')
@allowed([
  '1.2'
  '1.3'
])
param minTlsVersion string = '1.2'

@description('Health check path, e.g. /health. Empty to disable.')
param healthCheckPath string = ''

@description('Custom startup command (Linux only). Empty to use the platform default.')
param startupCommand string = ''

@description('Additional app settings as key/value pairs.')
param appSettings object = {}

@description('Application Insights connection string. Empty to skip monitoring settings.')
param appInsightsConnectionString string = ''

@description('Resource ID of a subnet (delegated to Microsoft.Web/serverFarms) for outbound VNet integration. Empty to disable.')
param vnetSubnetId string = ''

@description('Create a "staging" deployment slot (Standard tier or above).')
param createStagingSlot bool = false

var isLinux = osType == 'Linux'

var linuxStackPrefix = {
  dotnet: 'DOTNETCORE'
  node: 'NODE'
  python: 'PYTHON'
  java: 'JAVA'
  php: 'PHP'
}

// Stack-specific siteConfig for Windows apps.
var windowsStackConfig = {
  dotnet: {
    netFrameworkVersion: 'v${runtimeVersion}'
    metadata: [
      {
        name: 'CURRENT_STACK'
        value: 'dotnet'
      }
    ]
  }
  node: {
    metadata: [
      {
        name: 'CURRENT_STACK'
        value: 'node'
      }
    ]
  }
  python: {}
  java: {
    javaVersion: runtimeVersion
    javaContainer: 'JAVA'
    javaContainerVersion: 'SE'
    metadata: [
      {
        name: 'CURRENT_STACK'
        value: 'java'
      }
    ]
  }
  php: {
    phpVersion: runtimeVersion
    metadata: [
      {
        name: 'CURRENT_STACK'
        value: 'php'
      }
    ]
  }
}

var stackConfig = isLinux
  ? {
      linuxFxVersion: '${linuxStackPrefix[runtimeStack]}|${runtimeVersion}'
      appCommandLine: startupCommand
    }
  : windowsStackConfig[runtimeStack]

var monitoringSettings = empty(appInsightsConnectionString)
  ? {}
  : {
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: isLinux ? '~3' : '~2'
    }

var windowsNodeSettings = (!isLinux && runtimeStack == 'node')
  ? {
      WEBSITE_NODE_DEFAULT_VERSION: runtimeVersion
    }
  : {}

var mergedAppSettings = union(monitoringSettings, windowsNodeSettings, appSettings)

var appSettingsArray = [for setting in items(mergedAppSettings): {
  name: setting.key
  value: string(setting.value)
}]

var siteConfig = union(stackConfig, {
  alwaysOn: alwaysOn
  ftpsState: 'Disabled'
  http20Enabled: true
  minTlsVersion: minTlsVersion
  scmMinTlsVersion: minTlsVersion
  healthCheckPath: empty(healthCheckPath) ? null : healthCheckPath
  vnetRouteAllEnabled: !empty(vnetSubnetId)
  appSettings: appSettingsArray
})

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  kind: isLinux ? 'app,linux' : 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    clientAffinityEnabled: false
    virtualNetworkSubnetId: empty(vnetSubnetId) ? null : vnetSubnetId
    siteConfig: siteConfig
  }
}

resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = if (createStagingSlot) {
  parent: webApp
  name: 'staging'
  location: location
  tags: tags
  kind: isLinux ? 'app,linux' : 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    clientAffinityEnabled: false
    virtualNetworkSubnetId: empty(vnetSubnetId) ? null : vnetSubnetId
    siteConfig: siteConfig
  }
}

output id string = webApp.id
output name string = webApp.name
output defaultHostName string = webApp.properties.defaultHostName
output principalId string = webApp.identity.principalId
output stagingSlotHostName string = createStagingSlot ? stagingSlot!.properties.defaultHostName : ''
