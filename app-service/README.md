# Azure App Service – generic Bicep template

Reusable Bicep template that lets any developer stand up an Azure App Service
(web app) with sensible, secure defaults by editing a single parameters file.

## What gets deployed

| Resource | Name pattern | Notes |
|---|---|---|
| Resource group | `resourceGroupName` param | Created if it doesn't exist, in `location` |
| App Service Plan | `asp-<appName>-<env>` | Skipped if `existingAppServicePlanId` is set |
| Web App | `app-<appName>-<env>-<unique>` | System-assigned managed identity, HTTPS only, TLS 1.2+, FTPS disabled |
| Log Analytics workspace | `log-<appName>-<env>` | If `enableMonitoring = true` |
| Application Insights | `appi-<appName>-<env>` | Wired to the app via `APPLICATIONINSIGHTS_CONNECTION_STRING` |
| Staging slot | `<webapp>/staging` | If `createStagingSlot = true` (Standard tier or above) |

Deploy it with the shared scripts or workflow; see the [root README](../README.md):

```bash
./scripts/deploy.sh -p app-service/parameters/dev.bicepparam --what-if
```

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `resourceGroupName` | *(required)* | Resource group to create or update |
| `location` | *(required)* | Azure region for the resource group and all resources |
| `resourceGroupLocation` | same as `location` | Set only if the resource group already exists in another region |
| `appName` | *(required)* | Short name (2–20 chars) used in resource names |
| `environment` | `dev` | `dev`, `test`, `uat`, `prod` |
| `webAppName` | auto | Override the globally unique web app name |
| `tags` | `{}` | Extra tags (merged with `application`, `environment`, `managedBy`) |
| `osType` | `Linux` | `Linux` or `Windows` |
| `skuName` | `B1` | `F1`, `B1`, `S1`, `P0v3`, `P1v3`, … |
| `instanceCount` | `1` | Number of plan instances |
| `zoneRedundant` | `false` | Premium v3 with `instanceCount >= 3` |
| `existingAppServicePlanId` | `''` | Reuse an existing plan instead of creating one |
| `runtimeStack` | `dotnet` | `dotnet`, `node`, `python`, `java`, `php` |
| `runtimeVersion` | `8.0` | See table below |
| `startupCommand` | `''` | Custom startup command (Linux) |
| `healthCheckPath` | `''` | e.g. `/health` |
| `appSettings` | `{}` | Environment variables for the app |
| `enableMonitoring` | `true` | Deploy Log Analytics + Application Insights |
| `createStagingSlot` | `false` | Create a `staging` deployment slot |
| `vnetSubnetId` | `''` | Subnet (delegated to `Microsoft.Web/serverFarms`) for VNet integration |

`alwaysOn` is enabled automatically except on Free/Shared (`F*`/`D*`) SKUs, where it isn't supported.

### Runtime versions

| Stack | Linux `runtimeVersion` | Windows `runtimeVersion` |
|---|---|---|
| dotnet | `8.0`, `9.0` | `8.0`, `9.0` |
| node | `20-lts`, `22-lts` | `~20`, `~22` |
| python | `3.11`, `3.12` | *not supported on Windows* |
| java | `17-java17`, `21-java21` | `17`, `21` |
| php | `8.2`, `8.3` | *Linux recommended* |

List what your region supports: `az webapp list-runtimes --os linux` (or `--os windows`).

## Deploying your code

This template provisions infrastructure only. Deploy code afterwards with e.g.:

```bash
az webapp deploy -g rg-myapp-dev -n <webAppName> --src-path app.zip --type zip
```

or the `azure/webapps-deploy` GitHub Action. The `deploy` job of the infrastructure workflow
lists the outputs (web app name and URL) in its summary.
