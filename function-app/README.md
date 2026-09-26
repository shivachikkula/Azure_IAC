# Azure Functions – generic Bicep template

Creates a resource group and an Azure Functions app on the **Flex Consumption** plan
(Linux, serverless: pay per execution, scales to zero), with the storage account it needs
and optional Log Analytics + Application Insights.

## What gets deployed

| Resource | Name | Notes |
|---|---|---|
| Resource group | `resourceGroupName` param | Created if it doesn't exist, in `location` |
| Storage account | `stfn<appName><unique>` | Functions runtime storage + `app-package` container for deployments |
| Flex Consumption plan | `asp-<appName>-<env>-func` | SKU `FC1` |
| Function app | `func-<appName>-<env>-<unique>` | System-assigned managed identity, HTTPS only, TLS 1.2+, FTPS disabled |
| Log Analytics workspace | `log-<appName>-<env>` | If `enableMonitoring = true` |
| Application Insights | `appi-<appName>-<env>` | Wired to the app via `APPLICATIONINSIGHTS_CONNECTION_STRING` |

```bash
./scripts/deploy.sh -p function-app/parameters/dev.bicepparam --what-if
```

See the [root README](../README.md) for deploy scripts and the GitHub Actions setup.

Flex Consumption is available in most but not all regions. List them with
`az functionapp list-flexconsumption-locations -o table`.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `resourceGroupName` | *(required)* | Resource group to create or update |
| `location` | *(required)* | Azure region (must support Flex Consumption) |
| `resourceGroupLocation` | same as `location` | Set only if the resource group already exists in another region |
| `appName` | *(required)* | Short name (2–16 chars) used in resource names |
| `environment` | `dev` | `dev`, `test`, `uat`, `prod` |
| `functionAppName` | auto | Override the globally unique app name |
| `tags` | `{}` | Extra tags |
| `runtimeName` | `dotnet-isolated` | `dotnet-isolated`, `node`, `python`, `java`, `powershell` |
| `runtimeVersion` | `8.0` | e.g. dotnet-isolated `8.0`/`9.0`, node `20`/`22`, python `3.11`/`3.12`, java `17`/`21`, powershell `7.4` |
| `instanceMemoryMB` | `2048` | `512`, `2048` or `4096` |
| `maximumInstanceCount` | `100` | Scale-out limit (40–1000) |
| `appSettings` | `{}` | Environment variables for the app |
| `storageAuthentication` | `ConnectionString` | `ManagedIdentity` uses no storage keys but creates role assignments, which needs Owner or User Access Administrator on the deploying identity (Contributor isn't enough) |
| `enableMonitoring` | `true` | Deploy Log Analytics + Application Insights |

On Flex Consumption the runtime is set by `runtimeName`/`runtimeVersion`; don't add
`FUNCTIONS_WORKER_RUNTIME` or `FUNCTIONS_EXTENSION_VERSION` to `appSettings`.

## Outputs

`resourceGroupName`, `functionAppName`, `functionAppUrl`, `functionAppPrincipalId`, `storageAccountName`.

## Deploying your code

```bash
func azure functionapp publish <functionAppName>
```

or the `Azure/functions-action` GitHub Action.
