<#
.SYNOPSIS
  Deploy the App Service Bicep template.

.EXAMPLE
  ./scripts/deploy.ps1 -ResourceGroup rg-myapp-dev -Location eastus -ParametersFile parameters/dev.bicepparam -WhatIf
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $ResourceGroup,
  [Parameter(Mandatory)] [string] $ParametersFile,
  [string] $Location,
  [string] $Subscription,
  [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'
$template = Join-Path $PSScriptRoot '..' 'main.bicep'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw 'Azure CLI (az) is required: https://aka.ms/azure-cli'
}
if (-not (Test-Path $ParametersFile)) { throw "Parameters file not found: $ParametersFile" }

az account show 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { az login | Out-Null }
if ($Subscription) { az account set --subscription $Subscription }
Write-Host "Subscription: $(az account show --query name -o tsv)"

if ((az group exists --name $ResourceGroup) -ne 'true') {
  if (-not $Location) { throw "Resource group '$ResourceGroup' does not exist; pass -Location to create it." }
  Write-Host "Creating resource group $ResourceGroup in $Location..."
  az group create --name $ResourceGroup --location $Location --output none
}

$deploymentName = "appservice-$(Get-Date -Format 'yyyyMMddHHmmss')"

if ($WhatIf) {
  az deployment group what-if --resource-group $ResourceGroup --name $deploymentName `
    --template-file $template --parameters $ParametersFile
  exit $LASTEXITCODE
}

az deployment group create --resource-group $ResourceGroup --name $deploymentName `
  --template-file $template --parameters $ParametersFile `
  --query 'properties.outputs' --output json
exit $LASTEXITCODE
