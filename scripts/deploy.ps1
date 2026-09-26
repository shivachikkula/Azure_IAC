<#
.SYNOPSIS
  Deploy any template in this repo at subscription scope.
  The template comes from the parameters file's "using" line; the resource group
  name and location are read from its resourceGroupName and location parameters.

.EXAMPLE
  ./scripts/deploy.ps1 -ParametersFile storage-account/parameters/dev.bicepparam -WhatIf
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $ParametersFile,
  [string] $Subscription,
  [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw 'Azure CLI (az) is required: https://aka.ms/azure-cli'
}
if (-not (Test-Path $ParametersFile)) { throw "Parameters file not found: $ParametersFile" }

# Resolve the template from the parameters file's "using '<path>'" line (relative to the file).
$using = Select-String -Path $ParametersFile -Pattern "^using '([^']+)'" | Select-Object -First 1
if (-not $using) { throw "No ""using '<template>'"" line in $ParametersFile" }
$paramsDir = Split-Path -Parent (Resolve-Path $ParametersFile)
$template = [System.IO.Path]::GetFullPath((Join-Path $paramsDir $using.Matches[0].Groups[1].Value))
if (-not (Test-Path $template)) { throw "Template not found: $template" }

az account show 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { az login | Out-Null }
if ($Subscription) { az account set --subscription $Subscription }
Write-Host "Subscription: $(az account show --query name -o tsv)"

# Read the resource group and location from the parameters file.
$paramsJson = New-TemporaryFile
try {
  az bicep build-params --file $ParametersFile --outfile $paramsJson.FullName
  if ($LASTEXITCODE -ne 0) { throw "Failed to build $ParametersFile" }
  $params = (Get-Content $paramsJson.FullName -Raw | ConvertFrom-Json).parameters
} finally {
  Remove-Item $paramsJson.FullName -ErrorAction SilentlyContinue
}
$resourceGroup = $params.resourceGroupName.value
$location = $params.location.value
if (-not $resourceGroup -or -not $location) { throw "Set resourceGroupName and location in $ParametersFile" }
Write-Host "Template: $template"
Write-Host "Resource group: $resourceGroup ($location)"

$deploymentName = "$(Split-Path -Leaf (Split-Path -Parent $template))-$(Get-Date -Format 'yyyyMMddHHmmss')"

if ($WhatIf) {
  az deployment sub what-if --location $location --name $deploymentName `
    --template-file $template --parameters $ParametersFile
  exit $LASTEXITCODE
}

az deployment sub create --location $location --name $deploymentName `
  --template-file $template --parameters $ParametersFile `
  --query 'properties.outputs' --output json
exit $LASTEXITCODE
