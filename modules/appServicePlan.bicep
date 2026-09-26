// App Service Plan (server farm).

@description('Name of the App Service Plan.')
param name string

@description('Azure region for the plan.')
param location string

@description('Tags applied to the plan.')
param tags object = {}

@description('Operating system of the plan.')
@allowed([
  'Linux'
  'Windows'
])
param osType string

@description('SKU name, e.g. B1, S1, P1v3.')
param skuName string

@description('Number of worker instances.')
@minValue(1)
param capacity int = 1

@description('Spread instances across availability zones (Premium v3 only, requires capacity >= 3).')
param zoneRedundant bool = false

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: name
  location: location
  tags: tags
  kind: osType == 'Linux' ? 'linux' : 'app'
  sku: {
    name: skuName
    capacity: capacity
  }
  properties: {
    reserved: osType == 'Linux'
    zoneRedundant: zoneRedundant
  }
}

output id string = plan.id
output name string = plan.name
