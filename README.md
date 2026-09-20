# Simple GCS to Databricks Pipeline

One small dev pipeline:

```text
GCS landing folder -> Bronze notebook -> Silver notebook
```

Bronze stores the XML files as raw text. Silver parses the customer fields, keeps the newest row for each customer ID, and saves clean Delta data.

## Project layout

```text
README.md
main.tf
provider.tf
databricks/
  01_bronze_ingest.py
  02_silver_transform.py
sample-data/
  *.xml
```

## Requirements

- Terraform 1.6 or newer
- Google Cloud CLI
- An existing GCP Databricks workspace
- A Unity Catalog catalog named `workspace`
- Databricks authentication in `DATABRICKS_TOKEN`

The Terraform state bucket used by this dev project must exist:

```text
project-b142c40e-70d4-4124-9ee-xml-tfstate
```

Authenticate with Google Cloud:

```powershell
gcloud auth application-default login
```

Set Databricks authentication in PowerShell:

```powershell
$env:DATABRICKS_HOST = "https://your-databricks-workspace-url"
$env:DATABRICKS_TOKEN = "your-databricks-token"
```

## Deploy

Run these commands from the repository root, where `main.tf` is located:

```powershell
terraform init -reconfigure
terraform validate
terraform plan -var="gcp_project_id=YOUR_GCP_PROJECT_ID" -var="databricks_host=$env:DATABRICKS_HOST"
terraform apply -var="gcp_project_id=YOUR_GCP_PROJECT_ID" -var="databricks_host=$env:DATABRICKS_HOST"
```

Replace `YOUR_GCP_PROJECT_ID` with your real project ID. Type `yes` when Terraform asks for confirmation.

Upload the XML files to the bucket shown by Terraform:

```powershell
gcloud storage cp .\sample-data\*.xml gs://YOUR_BUCKET_NAME/landing/
```

Open Databricks Workflows and manually run `xml-lakehouse-dev`. The tasks run in this order:

```text
bronze -> silver
```

## Output tables

```text
workspace.bronze_dev.xml_raw
workspace.silver_dev.customers
```
