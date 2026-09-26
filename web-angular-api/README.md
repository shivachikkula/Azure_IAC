# Angular client + .NET API on App Service – Bicep template

Creates a resource group and one Linux App Service Plan hosting two web apps:

- **client** serves your built Angular app (the `dist/<project>/browser` output) as a single-page app.
  The startup command is `pm2 serve /home/site/wwwroot --no-daemon --spa`, so deep links such as
  `/orders/42` fall back to `index.html`.
- **api** runs your ASP.NET Core API. CORS allows the client app's URL, plus any `apiExtraCorsOrigins`.

## What gets deployed

| Resource | Name | Notes |
|---|---|---|
| Resource group | `resourceGroupName` param | Created if it doesn't exist, in `location` |
| App Service Plan | `asp-<appName>-<env>` | Linux, shared by both apps; skipped if `existingAppServicePlanId` is set |
| Client web app | `app-<appName>-<env>-web-<unique>` | Node runtime serving the Angular build |
| API web app | `app-<appName>-<env>-api-<unique>` | .NET runtime; system-assigned managed identity |
| Log Analytics workspace | `log-<appName>-<env>` | If `enableMonitoring = true` |
| Application Insights | `appi-<appName>-<env>` | Shared by both apps |

Both apps: HTTPS only, TLS 1.2+, FTPS disabled. Always On is turned on except on Free/Shared SKUs.

```bash
./scripts/deploy.sh -p web-angular-api/parameters/dev.bicepparam --what-if
```

See the [root README](../README.md) for deploy scripts and the GitHub Actions setup.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `resourceGroupName` | *(required)* | Resource group to create or update |
| `location` | *(required)* | Azure region |
| `resourceGroupLocation` | same as `location` | Set only if the resource group already exists in another region |
| `appName` | *(required)* | Short name (2–20 chars) used in resource names |
| `environment` | `dev` | `dev`, `test`, `uat`, `prod` |
| `tags` | `{}` | Extra tags |
| `skuName` | `B1` | Plan SKU shared by both apps: `F1`, `B1`, `S1`, `P0v3`, … |
| `instanceCount` | `1` | Number of plan instances |
| `existingAppServicePlanId` | `''` | Reuse an existing Linux plan instead of creating one |
| `clientNodeVersion` | `20-lts` | Node version used to serve the Angular build |
| `clientAppSettings` | `{}` | App settings for the client app |
| `apiDotnetVersion` | `8.0` | `8.0`, `9.0` |
| `apiHealthCheckPath` | `''` | e.g. `/health` |
| `apiAppSettings` | `{}` | App settings for the API (e.g. `ASPNETCORE_ENVIRONMENT`) |
| `apiExtraCorsOrigins` | `[]` | Extra origins allowed to call the API, e.g. `http://localhost:4200` or a custom domain |
| `enableMonitoring` | `true` | Deploy Log Analytics + Application Insights |

## Outputs

`resourceGroupName`, `clientAppName`, `clientUrl`, `apiAppName`, `apiUrl`, `apiPrincipalId`.

## Pointing Angular at the API

The Angular app is static, so the API URL is set at build time. Put the `apiUrl` output in the
environment file for that build, e.g. `src/environments/environment.development.ts`:

```ts
export const environment = {
  apiUrl: 'https://app-mywebapp-dev-api-<unique>.azurewebsites.net',
};
```

## Deploying your code

```bash
# Angular: build, then deploy the browser output folder
ng build --configuration production
(cd dist/<project>/browser && zip -r ../../../client.zip .)
az webapp deploy -g <rg> -n <clientAppName> --src-path client.zip --type zip

# .NET API
dotnet publish -c Release -o publish
(cd publish && zip -r ../api.zip .)
az webapp deploy -g <rg> -n <apiAppName> --src-path api.zip --type zip
```
