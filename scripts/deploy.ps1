param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "prod")]
    [string] $Environment,

    [Parameter(Mandatory = $true)]
    [string] $GcpProjectId,

    [Parameter(Mandatory = $true)]
    [string] $TerraformStateBucket,

    [Parameter(Mandatory = $true)]
    [string] $DatabricksHost,

    [string] $DatabricksStorageCredentialName,
    [switch] $Apply,
    [switch] $UploadSampleData
)

$ErrorActionPreference = "Stop"

$terraformCommand = Get-Command terraform -ErrorAction SilentlyContinue
if (-not $terraformCommand) {
    $terraformCommand = Get-ChildItem `
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" `
        -Filter terraform.exe `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
}
if (-not $terraformCommand) {
    throw "Terraform is required. Install Terraform with winget install Hashicorp.Terraform."
}
$terraform = $terraformCommand.Source
if (-not $terraform) { $terraform = $terraformCommand.FullName }

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    throw "Google Cloud CLI is required. Install gcloud and reopen PowerShell."
}

if (-not $env:DATABRICKS_TOKEN -and -not ($env:DATABRICKS_CLIENT_ID -and $env:DATABRICKS_CLIENT_SECRET)) {
    throw "Set DATABRICKS_TOKEN for local deployment or DATABRICKS_CLIENT_ID and DATABRICKS_CLIENT_SECRET for CI."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$terraformDirectory = Join-Path $repoRoot "terraform"
$backendPrefix = "xml-lakehouse/$Environment"
$variableArguments = @(
    "-var-file=environments/$Environment.tfvars"
    "-var=gcp_project_id=$GcpProjectId"
    "-var=databricks_host=$DatabricksHost"
)

if ($DatabricksStorageCredentialName) {
    $variableArguments += "-var=databricks_storage_credential_name=$DatabricksStorageCredentialName"
}

Push-Location $terraformDirectory
try {
    & $terraform init -reconfigure `
        "-backend-config=bucket=$TerraformStateBucket" `
        "-backend-config=prefix=$backendPrefix"
    if ($LASTEXITCODE -ne 0) { throw "Terraform init failed with exit code $LASTEXITCODE." }

    & $terraform fmt -check -recursive
    if ($LASTEXITCODE -ne 0) { throw "Terraform formatting check failed." }
    & $terraform validate
    if ($LASTEXITCODE -ne 0) { throw "Terraform validation failed." }

    if ($Apply) {
        & $terraform apply @variableArguments
        if ($LASTEXITCODE -ne 0) { throw "Terraform apply failed with exit code $LASTEXITCODE." }
        $landingUri = & $terraform output -raw landing_uri
        if ($LASTEXITCODE -ne 0) { throw "Terraform output failed with exit code $LASTEXITCODE." }
        Write-Host "Landing path: $landingUri"

        if ($UploadSampleData) {
            gcloud storage cp (Join-Path $repoRoot "sample-data\*.xml") "$landingUri/"
        }
    }
    else {
        & $terraform plan @variableArguments
        if ($LASTEXITCODE -ne 0) { throw "Terraform plan failed with exit code $LASTEXITCODE." }
        Write-Host "Plan complete. Re-run with -Apply to provision $Environment."
    }
}
finally {
    Pop-Location
}