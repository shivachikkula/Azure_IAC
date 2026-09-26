# Azure IaC

Reusable infrastructure for Azure in **Bicep** and **Terraform**. Teams pick whichever they prefer:
both deploy the same services (App Service, Angular + .NET API, Function App, Storage account)
with the same secure defaults, and both use the same GitHub environments and Azure credentials.

## Requesting services for a project

Copy an example project, switch on only the services you need, and open a pull request. You get a
preview of the changes, and merging deploys them.

| | Bicep | Terraform |
|---|---|---|
| Start here | [`projects/`](projects/README.md) | [`terraform/`](terraform/README.md) |
| Your file | `projects/<project>/dev.bicepparam` | `terraform/projects/<project>/dev.tfvars` |
| Pull request preview | what-if (**Deploy projects** workflow) | `terraform plan` (**Terraform projects** workflow) |
| On merge | deploy changed project files | plan + apply changed project files |
| State | none (Azure is the source of truth) | Azure Storage account (one-time bootstrap) |
| Switching a service off | leaves its resources in place | deletes its resources |

The rest of this page covers the Bicep side and the shared setup.

## Standalone templates

Each service also has its own template, deployed from `<template>/parameters/<environment>.bicepparam`
by running its workflow manually (merging doesn't deploy these):

| Template | Deploys |
|---|---|
| [`app-service/`](app-service/README.md) | App Service Plan + one Web App (.NET, Node, Python, Java or PHP), optional staging slot and VNet integration |
| [`web-angular-api/`](web-angular-api/README.md) | One plan hosting an Angular client app and a .NET API app, with CORS wired between them |
| [`function-app/`](function-app/README.md) | Azure Functions on a Flex Consumption plan, with its storage account |
| [`storage-account/`](storage-account/README.md) | StorageV2 account with secure defaults, plus optional containers, queues, tables and file shares |

Log Analytics + Application Insights are included (and can be turned off) in the app templates.

```
├── terraform/                 # Terraform option: modules, project root module, projects/
├── projects/                  # Bicep: request services per project
│   ├── main.bicep             #   one template with a switch per service
│   └── _example/              #   copy to projects/<your-project>/
├── modules/                   # Shared building blocks used by all templates
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
├── scripts/                   # deploy.sh / deploy.ps1 for any template or project file
└── .github/workflows/         # deploy-projects.yml, deploy-<template>.yml, shared _bicep-deploy.yml
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
   ./scripts/deploy.sh -p projects/orders/dev.bicepparam --what-if
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

| Workflow | Pull request | Push to `main` | Manual run |
|---|---|---|---|
| **Deploy projects** | Validate all project files; what-if each changed one (all of them if `projects/main.bicep` or `modules/` changed) | Deploy each project file changed by the push | Preview or deploy one project + environment |
| **Deploy &lt;template&gt;** (one per standalone template) | Validate; what-if `dev` | — | Deploy `dev` or `prod`, or preview only |
| **Terraform projects** | Format check, validate, plan each changed project file | Plan + apply each changed project file | Plan or apply one project + environment |

Both use the shared [`_bicep-deploy.yml`](.github/workflows/_bicep-deploy.yml). A project's
`dev.bicepparam` deploys with the `dev` GitHub environment's credentials, `prod.bicepparam` with `prod`'s.

To add a new service: add a module under `modules/`, a `deploy<Service>` switch and settings
block to `projects/main.bicep`, and optionally a standalone template folder with its own
`deploy-<template>.yml` (copy an existing one and change the folder name).

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
