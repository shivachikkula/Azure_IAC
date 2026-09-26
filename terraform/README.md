# Terraform: request only the services you need

The Terraform twin of the Bicep [`projects/`](../projects/README.md) setup. Teams can use either;
both deploy the same services with the same secure defaults and naming, and use the same
GitHub environments and Azure credentials.

| Variable | Deploys |
|---|---|
| `deploy_app_service` | A Linux web app (.NET, Node, Python, Java or PHP) |
| `deploy_web_angular_api` | An Angular client app + a .NET API app, CORS allows the client's URL |
| `deploy_function_app` | Azure Functions on Flex Consumption (serverless), with its own storage account |
| `deploy_storage_account` | A storage account for application data, with any containers, queues, tables or file shares |
| `enable_monitoring` | Log Analytics + Application Insights, shared by all the project's apps (on by default) |

The web apps share one Linux App Service Plan (`app_service_plan.sku_name`, default `B1`).

```
terraform/
├── project/            # Root module: one switch per service (main.tf, variables.tf, outputs.tf)
├── modules/            # web_app, function_app, storage_account, monitoring
├── projects/
│   └── _example/       # dev.tfvars, prod.tfvars; copy to projects/<your-project>/
├── bootstrap/          # create-state-storage.sh: one-time state storage setup
└── backend.hcl         # written by the bootstrap script; commit it
```

Requires Terraform 1.9+ and the `azurerm` provider 5.x.

## One-time setup: state storage

Terraform keeps state in an Azure Storage account. Create it once and commit the file it writes:

```bash
./terraform/bootstrap/create-state-storage.sh          # rg-tfstate in westus2 by default
git add terraform/backend.hcl && git commit -m "Add Terraform state backend"
```

Each project environment gets its own state file, `<project>/<environment>.tfstate`, in that account.
The GitHub identity's *Contributor* role on the subscription is enough: the backend reads the
account's access key.

The workflows reuse the Bicep setup: the `dev` and `prod` GitHub environments with the
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` secrets, and the same
federated credentials (see the [root README](../README.md#one-time-setup)).

## Request services

1. Copy the example and rename it for your project:

   ```bash
   cp -r terraform/projects/_example terraform/projects/orders
   ```

2. Edit `terraform/projects/orders/dev.tfvars`:
   - set `resource_group_name`, `location`, `project_name` and `tags`
   - set the `deploy_*` variables for the services you need, and `false` for the rest
   - adjust the settings objects for the services you switched on. Every attribute is optional.

3. Open a pull request. The **Terraform projects** workflow checks formatting, validates the modules
   and every `.tfvars` file, and posts a `terraform plan` for your file in the job summary.

4. Merge it. The workflow runs plan + apply for the files you changed: `dev.tfvars` with the `dev`
   GitHub environment, `prod.tfvars` with `prod` (which can require an approval). The job summary
   lists the resource names and URLs.

Unlike Bicep, Terraform **deletes** what you switch off: setting `deploy_storage_account = false`
destroys that storage account on the next apply. The plan shows this before you merge.

You can also run it by hand: *Actions → Terraform projects → Run workflow* with the project and
environment (tick *apply* to apply), or from your machine after `az login`:

```bash
cd terraform/project
terraform init -backend-config=../backend.hcl -backend-config="key=orders/dev.tfstate"
terraform plan -var-file=../projects/orders/dev.tfvars
terraform apply -var-file=../projects/orders/dev.tfvars
```

## Variables

| Variable | Default | Description |
|---|---|---|
| `resource_group_name` | *(required)* | The project's resource group, created by Terraform |
| `location` | *(required)* | Azure region for all resources |
| `project_name` | *(required)* | 2–16 lowercase letters, numbers or hyphens, used in resource names |
| `environment` | `dev` | `dev`, `test`, `uat`, `prod` |
| `tags` | `{}` | Extra tags (merged with `application`, `environment`, `managedBy`) |
| `deploy_app_service`, `deploy_web_angular_api`, `deploy_function_app`, `deploy_storage_account` | `false` | Services to deploy |
| `enable_monitoring` | `true` | Shared Log Analytics + Application Insights |
| `app_service_plan` | `{}` | `sku_name` (`B1`), `instance_count` (`1`) |
| `app_service` | `{}` | `runtime_stack` (`dotnet`), `runtime_version` (`8.0`), `startup_command`, `health_check_path`, `app_settings` |
| `web_angular_api` | `{}` | `client_node_version` (`20-lts`), `client_app_settings`, `api_dotnet_version` (`8.0`), `api_health_check_path`, `api_app_settings`, `api_extra_cors_origins` |
| `function_app` | `{}` | `runtime_name` (`dotnet-isolated`), `runtime_version` (`8.0`), `instance_memory_mb` (`2048`), `maximum_instance_count` (`100`), `app_settings`, `storage_authentication` (`ConnectionString`) |
| `storage_account` | `{}` | `replication_type` (`LRS`), `access_tier` (`Hot`), `shared_access_key_enabled` (`true`), `soft_delete_retention_days` (`7`), `versioning_enabled` (`false`), `containers`, `queues`, `tables`, `file_shares` |

Runtime versions use the Terraform provider's format, e.g. Java is `"17"` (Bicep uses `"17-java17"`).

## Resource names

Same patterns as Bicep, with a random 6-character suffix kept in state:
`asp-<project>-<env>`, `app-<project>-<env>-<suffix>`, `app-<project>-<env>-web-<suffix>` /
`-api-<suffix>`, `func-<project>-<env>-<suffix>`, `stfn<project><suffix>`, `st<project><env><suffix>`,
`log-<project>-<env>`, `appi-<project>-<env>`, plus tag `managedBy = terraform`.

## Notes

- A pull request that changes `terraform/project` or `terraform/modules` plans every project. Merging
  it applies nothing by itself; run the workflow manually per project to roll the change out.
- Only files named after an environment the workflow knows (`dev`, `prod`) are planned and applied.
  To add one, create the GitHub environment with the Azure secrets, then add it to `ENVIRONMENTS` in
  `scripts/changed-projects.sh` and the `options` list in `.github/workflows/terraform-projects.yml`.
- Don't manage the same resource group from both Bicep and Terraform.
