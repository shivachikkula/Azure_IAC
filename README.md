# Azure IaC

Reusable Bicep templates for Azure. Each template deploys at subscription scope,
creates its own resource group, and is driven entirely by a parameters file
(`<template>/parameters/<environment>.bicepparam`) that also names the resource group and region.

| Template | Deploys |
|---|---|
| [`app-service/`](app-service/README.md) | App Service Plan + one Web App (.NET, Node, Python, Java or PHP), optional staging slot and VNet integration |
| [`web-angular-api/`](web-angular-api/README.md) | One plan hosting an Angular client app and a .NET API app, with CORS wired between them |
| [`function-app/`](function-app/README.md) | Azure Functions on a Flex Consumption plan, with its storage account |
| [`storage-account/`](storage-account/README.md) | StorageV2 account with secure defaults, plus optional containers, queues, tables and file shares |

Log Analytics + Application Insights are included (and can be turned off) in the app templates.

```
├── modules/                   # Shared building blocks used by the templates
│   ├── appServicePlan.bicep
│   ├── webApp.bicep
│   ├── functionApp.bicep
│   ├── storageAccount.bicep
│   └── monitoring.bicep
├── app-service/               # One folder per template:
│   ├── main.bicep             #   entry point (subscription scope)
│   ├── parameters/            #   dev.bicepparam, prod.bicepparam, ...
│   └── README.md
├── web-angular-api/
├── function-app/
├── storage-account/
├── scripts/                   # deploy.sh / deploy.ps1 for any template
└── .github/workflows/         # _bicep-deploy.yml (shared) + deploy-<template>.yml
```

## Prerequisites

- [Azure CLI](https://aka.ms/azure-cli) 2.53+ (includes Bicep; run `az bicep upgrade` to update)
- Contributor rights on the target subscription (templates create their resource group)
- `jq` for the Bash deploy script

## Deploy from your machine

1. Edit (or copy) a parameters file, including the target resource group and region:

   ```bicep
   param resourceGroupName = 'rg-myapp-dev'
   param location = 'westus2'
   ```

2. Preview, then deploy. The scripts find the template from the parameters file's `using` line and
   read the resource group and location from it:

   ```bash
   ./scripts/deploy.sh -p storage-account/parameters/dev.bicepparam --what-if
   ./scripts/deploy.sh -p storage-account/parameters/dev.bicepparam
   ```

   ```powershell
   ./scripts/deploy.ps1 -ParametersFile storage-account/parameters/dev.bicepparam -WhatIf
   ```

   Or use the Azure CLI directly from a template folder. `-l` is where Azure stores the deployment
   record; use the same region as `location`:

   ```bash
   cd storage-account
   az deployment sub create -l westus2 -f main.bicep -p parameters/dev.bicepparam
   ```

   You can override any value on the command line, e.g. `-p parameters/dev.bicepparam -p skuName=S1`
   (requires a recent Azure CLI).

If a deployment fails with `SubscriptionIsOverQuotaForSku`, the subscription has no App Service
quota for that SKU in that region: change `location` or `skuName`, or request quota via
*Help + support → Create a support request → Service and subscription limits (quotas)*.

## CI/CD with GitHub Actions

Each template has a workflow, `.github/workflows/deploy-<template>.yml`, that calls the shared
[`_bicep-deploy.yml`](.github/workflows/_bicep-deploy.yml). It runs when the template folder,
`modules/` or the workflows change:

| Trigger | What happens |
|---|---|
| Pull request | Compile the template and all its parameter files, then run **what-if** against `dev` (result in the job summary) |
| Push to `main` | Compile, then **deploy** to `dev` |
| Manual (*Run workflow*) | Pick `dev` or `prod`, then deploy, or tick *whatIfOnly* to preview only |

A change under `modules/` triggers every template's workflow, so merging it deploys all templates to `dev`.
To add an environment, add `<template>/parameters/<env>.bicepparam`, a GitHub environment with the same
name, and the name to the workflow's `options` list.

To add a new template: create `<name>/main.bicep` (subscription scope, with `resourceGroupName` and
`location` parameters) and `<name>/parameters/dev.bicepparam`, then copy one of the
`deploy-<template>.yml` callers and change the folder name in it.

### One-time setup

The workflows sign in to Azure with OpenID Connect (OIDC), so no client secret is stored in GitHub.

1. **Create an identity for GitHub** (app registration + service principal):

   ```bash
   APP_ID=$(az ad app create --display-name gh-azure-iac --query appId -o tsv)
   az ad sp create --id "$APP_ID"
   ```

2. **Add a federated credential for each GitHub environment** (`dev`, `prod`).

   The subject must exactly match the `sub` claim GitHub sends. Newer repositories use a
   format that includes the owner and repository IDs, e.g.
   `repo:<owner>@<owner-id>/<repo>@<repo-id>:environment:dev`; older ones use
   `repo:<owner>/<repo>:environment:dev`. To see which one your repo uses, run a workflow once:
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

3. **Grant access.** The templates deploy at subscription scope and create their resource groups,
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
   `<template>/parameters/<environment>.bicepparam`; no GitHub variables are needed.

   Add *Required reviewers* to `prod` so production deploys wait for approval.

## Secrets

Don't put secrets in app settings. Store them in Key Vault, grant the app's managed identity
(the `...PrincipalId` output) *Key Vault Secrets User*, and use a Key Vault reference as the value:

```bicep
param appSettings = {
  DB_PASSWORD: '@Microsoft.KeyVault(SecretUri=https://kv-myapp.vault.azure.net/secrets/db-password/)'
}
```

## Validate locally

```bash
az bicep build --file app-service/main.bicep
az bicep build-params --file app-service/parameters/dev.bicepparam
```
