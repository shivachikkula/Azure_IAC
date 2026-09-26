// Example: Node.js on a Windows plan.
using '../main.bicep'

param appName = 'mynodeapp'
param environment = 'dev'
param osType = 'Windows'
param skuName = 'S1'
param runtimeStack = 'node'
param runtimeVersion = '~20'
param appSettings = {
  NODE_ENV: 'development'
}
