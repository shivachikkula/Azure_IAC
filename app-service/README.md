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

```
app-service/
├── main.bicep                     # Entry point
├── modules/
│   ├── appServicePlan.bicep
│   ├── webApp.bicep
│   └── monitoring.bicep
├── parameters/
│   ├── dev.bicepparam
│   ├── prod.bicepparam
│   └── node-windows.example.bicepparam
└── scripts/
    ├── deploy.sh                  # Bash
    └── deploy.ps1                 # PowerShell 7+
```

## Prerequisites

- [Azure CLI](https://aka.ms/azure-cli) 2.53+ (includes Bicep; run `az bicep upgrade` to update)
- Contributor rights on the target subscription (the template deploys at subscription scope so it can create the resource group)

## Quick start

1. Copy a parameters file and edit it for your app, including the target resource group and region:

   ```bash
   cp parameters/dev.bicepparam parameters/myapp-dev.bicepparam
   ```

   ```bicep
   param resourceGroupName = 'rg-myapp-dev'
   param location = 'eastus'
   ```

2. Preview the changes:

   ```bash
   ./scripts/deploy.sh -p parameters/myapp-dev.bicepparam --what-if
   ```

3. Deploy:

   ```bash
   ./scripts/deploy.sh -p parameters/myapp-dev.bicepparam
   ```

   PowerShell:

   ```powershell
   ./scripts/deploy.ps1 -ParametersFile parameters/myapp-dev.bicepparam
   ```

   The scripts read `resourceGroupName` and `location` from the parameters file (the Bash script needs `jq`).
   Or deploy directly with the Azure CLI. `-l` is where Azure stores the deployment record; use the same region:

   ```bash
   az deployment sub create -l eastus -f main.bicep -p parameters/myapp-dev.bicepparam
   ```

   You can override any value on the command line, e.g. `-p parameters/dev.bicepparam -p skuName=S1`
   (requires a recent Azure CLI).

The deployment prints the resource group, web app name, URL and managed identity principal ID.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `resourceGroupName` | *(required)* | Resource group to create or update |
| `location` | *(required)* | Azure region for the resource group and all resources |
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

## CI/CD with GitHub Actions

[`.github/workflows/deploy-app-service.yml`](../.github/workflows/deploy-app-service.yml) runs on changes under `app-service/`:

| Trigger | What happens |
|---|---|
| Pull request | Compile the template and all parameter files, then run **what-if** against `dev` (result goes in the job summary) |
| Push to `main` | Compile, then **deploy** to `dev` |
| Manual (*Run workflow*) | Pick `dev` or `prod`, then deploy, or tick *whatIfOnly* to preview only |

The workflow uses `parameters/<environment>.bicepparam`, so add a matching file for any new environment
(and add it to the `options` list in the workflow).

### One-time setup

The workflow signs in to Azure with OpenID Connect (OIDC), so no client secret is stored in GitHub.

1. **Create an identity for GitHub** (app registration + service principal):

   ```bash
   APP_ID=$(az ad app create --display-name gh-azure-iac --query appId -o tsv)
   az ad sp create --id "$APP_ID"
   ```

2. **Add a federated credential for each GitHub environment** (`dev`, `prod`).

   The subject must exactly match the `sub` claim GitHub sends. Newer repositories use a
   format that includes the owner and repository IDs, e.g.
   `repo:<owner>@<owner-id>/<repo>@<repo-id>:environment:dev`; older ones use
   `repo:<owner>/<repo>:environment:dev`. To see which one your repo uses, run the workflow once:
   the `azure/login` step prints the `subject claim` it presented. You can also build the ID-based
   prefix with the GitHub CLI:

   ```bash
   SUBJECT_PREFIX=$(gh api repos/<owner>/<repo> --jq '"repo:\(.owner.login)@\(.owner.id)/\(.name)@\(.id)"')
   # or, for the legacy format: SUBJECT_PREFIX="repo:<owner>/<repo>"
   ```

   ```bash
   for env in dev prod; do
     az ad app federated-credential create --id "$APP_ID" --parameters "{
       \"name\": \"github-$env\",
       \"issuer\": \"https://token.actions.githubusercontent.com\",
       \"subject\": \"$SUBJECT_PREFIX:environment:$env\",
       \"audiences\": [\"api://AzureADTokenExchange\"]
     }"
   done
   ```

3. **Grant access.** The template deploys at subscription scope and creates the resource group,
   so the identity needs *Contributor* on the subscription:

   ```bash
   az role assignment create --assignee "$APP_ID" --role Contributor \
     --scope /subscriptions/<subscription-id>
   ```

4. **Create GitHub environments** `dev` and `prod` (*Settings → Environments*) and add to each:

   | Kind | Name | Value |
   |---|---|---|
   | Secret | `AZURE_CLIENT_ID` | `$APP_ID` |
   | Secret | `AZURE_TENANT_ID` | `az account show --query tenantId -o tsv` |
   | Secret | `AZURE_SUBSCRIPTION_ID` | `az account show --query id -o tsv` |

   The resource group and region come from `resourceGroupName` and `location` in
   `parameters/<environment>.bicepparam`; no GitHub variables are needed.

   Add *Required reviewers* to `prod` so production deploys wait for approval.

## Secrets

Don't put secrets in `appSettings`. Store them in Key Vault, grant the web app's
managed identity (`webAppPrincipalId` output) *Key Vault Secrets User*, and use a
Key Vault reference as the value:

```bicep
param appSettings = {
  DB_PASSWORD: '@Microsoft.KeyVault(SecretUri=https://kv-myapp.vault.azure.net/secrets/db-password/)'
}
```

## Deploying your code

This template provisions infrastructure only. Deploy code afterwards with e.g.:

```bash
az webapp deploy -g rg-myapp-dev -n <webAppName> --src-path app.zip --type zip
```

or the `azure/webapps-deploy` GitHub Action. The infrastructure workflow exposes the web app
name as the `webAppName` output of its `deploy` job, which an app deployment job can consume.

## Validate locally

```bash
az bicep build --file main.bicep          # compile / lint
az bicep build-params --file parameters/dev.bicepparam
```
