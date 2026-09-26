// Function App on a Flex Consumption plan (Linux, serverless, scales to zero).
// Uses an existing storage account for the Functions runtime (AzureWebJobsStorage)
// and for the deployment package container.

@description('Globally unique name of the function app.')
param name string

@description('Name of the Flex Consumption plan to create.')
param planName string

@description('Azure region for the plan and app.')
param location string

@description('Tags applied to the plan and app.')
param tags object = {}

@description('Name of an existing storage account in this resource group.')
param storageAccountName string

@description('Blob container (in the storage account) that holds the deployment package. Must already exist.')
param deploymentContainerName string

@description('How the app authenticates to storage. "ManagedIdentity" also creates role assignments, which needs Owner or User Access Administrator on the deploying identity.')
@allowed([
  'ConnectionString'
  'ManagedIdentity'
])
param storageAuthentication string = 'ConnectionString'

@description('Worker runtime.')
@allowed([
  'dotnet-isolated'
  'node'
  'python'
  'java'
  'powershell'
])
param runtimeName string

@description('Runtime version, e.g. dotnet-isolated "8.0", node "20", python "3.11", java "17", powershell "7.4".')
param runtimeVersion string

@description('Memory per instance in MB.')
@allowed([
  512
  2048
  4096
])
param instanceMemoryMB int = 2048

@description('Maximum number of instances the app can scale out to.')
@minValue(40)
@maxValue(1000)
param maximumInstanceCount int = 100

@description('Additional app settings as key/value pairs.')
param appSettings object = {}

@description('Application Insights connection string. Empty to skip monitoring settings.')
param appInsightsConnectionString string = ''

var useIdentity = storageAuthentication == 'ManagedIdentity'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

// Storage and monitoring settings are built as plain arrays (not with a loop) because the
// connection string uses listKeys(), which is only known during deployment.
var storageSettings = useIdentity
  ? [
      {
        name: 'AzureWebJobsStorage__accountName'
        value: storage.name
      }
    ]
  : [
      {
        name: 'AzureWebJobsStorage'
        value: storageConnectionString
      }
      {
        name: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
        value: storageConnectionString
      }
    ]

var monitoringSettings = empty(appInsightsConnectionString)
  ? []
  : [
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsightsConnectionString
      }
    ]

var customSettings = [for setting in items(appSettings): {
  name: setting.key
  value: string(setting.value)
}]

var appSettingsArray = concat(storageSettings, monitoringSettings, customSettings)

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: name
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: appSettingsArray
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}${deploymentContainerName}'
          authentication: useIdentity
            ? {
                type: 'SystemAssignedIdentity'
              }
            : {
                type: 'StorageAccountConnectionString'
                storageAccountConnectionStringName: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
              }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: instanceMemoryMB
        maximumInstanceCount: maximumInstanceCount
      }
      runtime: {
        name: runtimeName
        version: runtimeVersion
      }
    }
  }
}

// Built-in roles the Functions runtime needs when it uses its managed identity.
var storageRoleIds = [
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88' // Storage Queue Data Contributor
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Storage Table Data Contributor
]

resource storageRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleId in storageRoleIds: if (useIdentity) {
  name: guid(storage.id, functionApp.id, roleId)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

output id string = functionApp.id
output name string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName
output principalId string = functionApp.identity.principalId
