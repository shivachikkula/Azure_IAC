# Projects: request only the services you need

Each team or app gets a folder here with one parameters file per environment. The file
switches on the services the project needs; everything goes into the project's own
resource group, built from the shared [modules](../modules).

| Switch | Deploys |
|---|---|
| `deployAppService` | A web app (.NET, Node, Python, Java or PHP) |
| `deployWebAngularApi` | An Angular client app + a .NET API app, CORS allows the client's URL |
| `deployFunctionApp` | Azure Functions on Flex Consumption (serverless), with its own storage account |
| `deployStorageAccount` | A storage account for application data, with any containers, queues, tables or file shares |
| `enableMonitoring` | Log Analytics + Application Insights, shared by all the project's apps (on by default) |

The web apps share one Linux App Service Plan (`appServicePlan.skuName`, default `B1`).

## Request services

1. Copy the example and rename it for your project:

   ```bash
   cp -r projects/_example projects/orders
   ```

2. Edit `projects/orders/dev.bicepparam`:
   - set `resourceGroupName`, `location`, `projectName` and `tags`
   - set the `deploy*` switches for the services you need, and `false` for the rest
   - adjust the settings blocks for the services you switched on. Every property is optional,
     so you can delete ones you're happy with the defaults for. Settings for services that are
     switched off are ignored.

3. Open a pull request. The **Deploy projects** workflow validates your file and posts a
   **what-if** preview of exactly what would be created in the job summary.

4. Merge it. The workflow deploys the files you changed: `dev.bicepparam` to the `dev` GitHub
   environment, `prod.bicepparam` to `prod` (which can require an approval). The job summary
   lists the resource names and URLs.

To change a project later, edit its file and repeat. Turning a switch off does **not** delete
the resources it created; delete those in the portal or with `az resource delete`.

You can also run it by hand: *Actions → Deploy projects → Run workflow*, with the project name
and environment (tick *whatIfOnly* to preview only), or from your machine:

```bash
./scripts/deploy.sh -p projects/orders/dev.bicepparam --what-if
```

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `resourceGroupName` | *(required)* | The project's resource group, created if it doesn't exist |
| `location` | *(required)* | Azure region for all resources |
| `resourceGroupLocation` | same as `location` | Set only if the resource group already exists in another region |
| `projectName` | *(required)* | Short name (2–16 chars) used in resource names |
| `environment` | `dev` | `dev`, `test`, `uat`, `prod` |
| `tags` | `{}` | Extra tags (merged with `application`, `environment`, `managedBy`) |
| `deployAppService`, `deployWebAngularApi`, `deployFunctionApp`, `deployStorageAccount` | `false` | Services to deploy |
| `enableMonitoring` | `true` | Shared Log Analytics + Application Insights |
| `appServicePlan` | `{}` | `skuName` (`B1`), `instanceCount` (`1`) |
| `appService` | `{}` | `runtimeStack` (`dotnet`), `runtimeVersion` (`8.0`), `startupCommand`, `healthCheckPath`, `appSettings` |
| `webAngularApi` | `{}` | `clientNodeVersion` (`20-lts`), `clientAppSettings`, `apiDotnetVersion` (`8.0`), `apiHealthCheckPath`, `apiAppSettings`, `apiExtraCorsOrigins` |
| `functionApp` | `{}` | `runtimeName` (`dotnet-isolated`), `runtimeVersion` (`8.0`), `instanceMemoryMB` (`2048`), `maximumInstanceCount` (`100`), `appSettings`, `storageAuthentication` (`ConnectionString`) |
| `storageAccount` | `{}` | `skuName` (`Standard_LRS`), `accessTier` (`Hot`), `allowSharedKeyAccess` (`true`), `softDeleteRetentionDays` (`7`), `enableVersioning` (`false`), `containers`, `queues`, `tables`, `fileShares` |

Details for each service (runtime versions, how to deploy your code) are in the standalone
templates' READMEs: [app-service](../app-service/README.md), [web-angular-api](../web-angular-api/README.md),
[function-app](../function-app/README.md), [storage-account](../storage-account/README.md).

## Resource names

| Resource | Name |
|---|---|
| App Service Plan | `asp-<project>-<env>` |
| Web app | `app-<project>-<env>-<unique>` |
| Angular client / .NET API | `app-<project>-<env>-web-<unique>` / `app-<project>-<env>-api-<unique>` |
| Function app + its plan | `func-<project>-<env>-<unique>`, `asp-<project>-<env>-func` |
| Function runtime storage | `stfn<project><unique>` |
| Data storage account | `st<project><env><unique>` |
| Log Analytics / App Insights | `log-<project>-<env>` / `appi-<project>-<env>` |

## Notes

- Only files named after an environment the workflow knows (`dev`, `prod`) are previewed and
  deployed. To add one (e.g. `test`), create the GitHub environment with the Azure secrets, then add
  it to `ENVIRONMENTS` in `scripts/changed-projects.sh` and to the `options` list in
  `.github/workflows/deploy-projects.yml`.
- A pull request that changes `projects/main.bicep` or `modules/` previews every project. Merging
  it deploys nothing by itself; redeploy a project with a manual run to pick up the change.
- Pull request previews for `prod` files run in the `prod` environment, so they wait for its
  required reviewers too.
