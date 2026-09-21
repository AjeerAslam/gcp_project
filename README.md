# Terraform XML Lakehouse Demo

A small Terraform project that provisions a GCS landing bucket and a Databricks Bronze-to-Silver pipeline.

```text
XML files -> GCS -> Bronze table -> Silver table
```

## Project structure

```text
main.tf                 Shared module composition
providers.tf            Providers and remote state
variables.tf            Shared input definitions
outputs.tf              Shared outputs
modules/                Reusable infrastructure
  gcs_landing/          GCS bucket, service account, and IAM
  databricks_storage_access/  Unity Catalog access to the GCS landing path
  databricks_pipeline/  Databricks schemas, notebooks, and job
environments/            Environment-specific values
  dev/
    terraform.tfvars.example
  prod/
    terraform.tfvars.example
databricks/              Shared notebook source code
sample-data/             Demo XML files
```

The root Terraform code is shared. The `environments/dev` and `environments/prod` folders contain only values. Terraform workspaces keep their remote state separate:

```text
dev workspace  -> xml-lakehouse/dev
prod workspace -> xml-lakehouse/prod
```

## Prerequisites

- Terraform 1.6+
- Google Cloud CLI with Application Default Credentials
- GCP Databricks workspace for each environment
- Unity Catalog catalog named `workspace`
- Databricks authentication through `DATABRICKS_HOST` and `DATABRICKS_TOKEN`
- Existing GCS state bucket: `project-b142c40e-70d4-4124-9ee-xml-tfstate`
- A Unity Catalog admin must be allowed to create storage credentials and external locations

Authenticate with Google Cloud:

```powershell
gcloud auth application-default login
```

Set Databricks authentication:

```powershell
$env:DATABRICKS_HOST = "https://your-databricks-workspace-url"
$env:DATABRICKS_TOKEN = "your-databricks-token"
```

## Initialize Terraform

Run all Terraform commands from the repository root:

```powershell
terraform init
```

## Deploy dev

Create the local dev values file, edit the placeholders, and select the matching workspace:

```powershell
Copy-Item environments\dev\terraform.tfvars.example environments\dev\terraform.tfvars
terraform workspace new dev
terraform workspace select dev
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"
```

If the `dev` workspace already exists, use:

```powershell
terraform workspace select dev
```

## Deploy prod

Create the local prod values file, edit the placeholders, and select the matching workspace:

```powershell
Copy-Item environments\prod\terraform.tfvars.example environments\prod\terraform.tfvars
terraform workspace new prod
terraform workspace select prod
terraform plan -var-file="environments/prod/terraform.tfvars"
terraform apply -var-file="environments/prod/terraform.tfvars"
```

If the `prod` workspace already exists, use:

```powershell
terraform workspace select prod
```

Always confirm the selected workspace before applying:

```powershell
terraform workspace show
```

The workspace controls the environment name in resource names, schemas, notebook paths, and job names. The matching variable file supplies the GCP project and Databricks workspace.

Terraform also creates the Unity Catalog storage access:

```text
GCS bucket -> Databricks GCP storage credential -> external location -> READ_FILES grant
```

The storage credential creates a Databricks-managed GCP service account. Terraform grants that identity read-only object access to the landing bucket, registers the landing path as an external location, and grants `READ_FILES` to `databricks_run_as` (default: `ajeeraslam@gmail.com`). The job uses the same user as its run-as identity.

The bucket receives object access plus bucket-reader access because Databricks validates both the objects and the GCS bucket metadata when creating the external location.

If `bronze_dev` or `silver_dev` already exists from an earlier manual deployment, import them before applying:

```powershell
terraform import "module.pipeline.databricks_schema.bronze" "workspace.bronze_dev"
terraform import "module.pipeline.databricks_schema.silver" "workspace.silver_dev"
```

Existing resources must be imported into the selected workspace state; Terraform cannot create a second resource with the same name.

## Run the pipeline

After applying, upload the sample XML files to the selected environment's bucket:

```powershell
gcloud storage cp .\sample-data\*.xml gs://$(terraform output -raw bucket_name)/landing/
```

Run the Databricks job. Its tasks run in this order:

```text
bronze -> silver
```

## GitHub Actions production deployment

Dev deployment and testing can remain manual from the CLI. After the tested change is merged into `master`, [production.yml](.github/workflows/production.yml) automatically runs the production Terraform deployment. The same workflow can also be started with one click from the GitHub Actions tab using **Run workflow**.

Create a GitHub Environment named `production` and configure required reviewers if you want an approval before the production apply. Add these repository or environment secrets:

```text
GCP_PROD_CREDENTIALS     Google service-account JSON for Terraform
PROD_GCP_PROJECT_ID      Production GCP project ID
PROD_DATABRICKS_HOST     Production Databricks workspace URL
PROD_DATABRICKS_TOKEN    Production Databricks token
```

Add these repository or environment variables:

```text
PROD_GCP_REGION          asia-south1
DATABRICKS_CATALOG        workspace
DATABRICKS_RUN_AS         Databricks production run-as user
```

The workflow authenticates to GCP, initializes the GCS backend, selects the `prod` Terraform workspace, validates the code, creates a plan, and applies that exact plan. The workflow does not upload sample data; production input files should be managed separately.

## Terraform concepts demonstrated

- **Modules:** reusable GCS and Databricks infrastructure.
- **Storage access module:** connects GCS IAM with the Unity Catalog external location.
- **Workspaces:** separate dev and prod state using the same Terraform code.
- **Variables:** environment-specific project IDs and workspace URLs.
- **Remote state:** GCS stores state outside the local machine.
- **Outputs:** expose the selected environment's bucket, landing path, job ID, and tables.
- **Dependencies:** Terraform and Databricks create resources in the required order.
