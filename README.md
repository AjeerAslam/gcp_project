# XML Lakehouse Terraform Demo

Terraform provisions a GCS landing bucket and a Databricks Bronze-to-Silver pipeline.

```text
XML files -> GCS -> Bronze -> Silver
```

## Structure

```text
main.tf                 Module connections
providers.tf            Providers and remote state
variables.tf            Inputs
outputs.tf              Outputs
modules/                Reusable GCS and Databricks modules
environments/dev/       Dev values
environments/prod/      Prod values
databricks/             Notebook source
.github/workflows/      Production deployment
```

## Requirements

- Terraform 1.6+
- Google Cloud CLI
- GCP Databricks workspaces
- Unity Catalog catalog: `workspace`
- Existing state bucket: `project-b142c40e-70d4-4124-9ee-xml-tfstate`

Set Databricks credentials before running Terraform:

```powershell
$env:DATABRICKS_HOST = "https://your-databricks-workspace-url"
$env:DATABRICKS_TOKEN = "your-databricks-token"
```

## Dev deployment

```powershell
terraform init
terraform workspace select -or-create dev
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"
```

Upload test data:

```powershell
gcloud storage cp .\sample-data\*.xml gs://$(terraform output -raw bucket_name)/landing/
```

## Prod deployment

```powershell
terraform workspace select -or-create prod
terraform plan -var-file="environments/prod/terraform.tfvars"
terraform apply -var-file="environments/prod/terraform.tfvars"
```

Check the selected workspace before applying:

```powershell
terraform workspace show
```

## GitHub Actions

After tested code is merged into `master`, `.github/workflows/production.yml` deploys the `prod` workspace. It uses GitHub OIDC and Workload Identity Federation, so no GCP JSON key is needed.

Configure a GitHub `production` environment with these secrets:

```text
PROD_GCP_PROJECT_ID
PROD_DATABRICKS_HOST
PROD_DATABRICKS_TOKEN
```

Add these variables:

```text
PROD_GCP_REGION
DATABRICKS_CATALOG
DATABRICKS_RUN_AS
```

## Terraform concepts

Providers, remote state, workspaces, variables, modules, outputs, dependencies, and CI/CD..
