# Azure Storage account – generic Bicep template

Creates a resource group and a StorageV2 account with secure defaults, plus any blob
containers, queues, tables and file shares listed in the parameters file.

## What gets deployed

| Resource | Name | Notes |
|---|---|---|
| Resource group | `resourceGroupName` param | Created if it doesn't exist, in `location` |
| Storage account | `st<appName><env><unique>` (max 24 chars) | Or set `storageAccountName` |
| Blob containers, queues, tables, file shares | as listed | Containers are always private |

Security defaults: HTTPS only, TLS 1.2 minimum, no anonymous blob access, no cross-tenant
replication, blob and container soft delete (7 days by default).

```bash
./scripts/deploy.sh -p storage-account/parameters/dev.bicepparam --what-if
```

See the [root README](../README.md) for deploy scripts and the GitHub Actions setup.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `resourceGroupName` | *(required)* | Resource group to create or update |
| `location` | *(required)* | Azure region |
| `appName` | *(required)* | Short name (2–10 chars) used in the account name |
| `environment` | `dev` | `dev`, `test`, `uat`, `prod` |
| `storageAccountName` | auto | Override the globally unique account name (3–24 lowercase letters/numbers) |
| `tags` | `{}` | Extra tags (merged with `application`, `environment`, `managedBy`) |
| `skuName` | `Standard_LRS` | Replication: `Standard_LRS` (cheapest), `Standard_ZRS`, `Standard_GRS`, `Standard_GZRS`, … |
| `accessTier` | `Hot` | `Hot`, `Cool`, `Cold` |
| `allowSharedKeyAccess` | `true` | `false` requires Microsoft Entra ID (managed identity) access; connection strings stop working |
| `publicNetworkAccess` | `true` | `false` when the account is only reached through private endpoints |
| `softDeleteRetentionDays` | `7` | Days to keep deleted blobs and containers (`0` disables) |
| `enableVersioning` | `false` | Keep previous blob versions |
| `containers` | `[]` | Blob container names |
| `queues` | `[]` | Queue names |
| `tables` | `[]` | Table names |
| `fileShares` | `[]` | File share names |

## Outputs

`resourceGroupName`, `storageAccountName`, `storageAccountId`, `blobEndpoint`.

## Giving an app access

Prefer managed identity over keys: grant the app's identity a data role on the account, e.g.

```bash
az role assignment create --assignee <app-principal-id> --role "Storage Blob Data Contributor" \
  --scope <storageAccountId>
```
