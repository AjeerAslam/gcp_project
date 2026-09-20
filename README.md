# GCP + Databricks XML Lakehouse

A deliberately small end-to-end data engineering project that shows the boundary between Terraform, Google Cloud Storage (GCS), and Databricks.

```
10 XML files in GCS landing/
          │
          ▼
Databricks job (daily 19:00 Asia/Kolkata)
          │
          ├── Bronze: raw XML text + filename + ingestion timestamp (Delta)
          │
          └── Silver: dynamically inferred XML schema, required-field validation,
                       null handling, de-duplication (Delta)
```

Terraform owns the infrastructure and job definition. Spark owns runtime data discovery: Terraform cannot know the XML columns until the job reads a file, so the pipeline creates/evolves the Bronze and Silver Delta tables from the XML payload. Terraform does create the catalog/schema namespace where the tables live.

## What is provisioned

- A private, versioned GCS bucket with `landing`, `checkpoint`, and `bad-records` prefixes.
- A least-privilege Google service account with access to that bucket.
- Databricks catalog and `bronze` / `silver` schemas.
- Two workspace notebooks and an ordered Databricks workflow.
- The workflow schedule, set to 7:00 PM every day in `Asia/Kolkata` by default.

The Databricks workspace itself is intentionally an input. Creating a GCP Databricks account/workspace is usually a separately governed account-administration process. This keeps the example usable with an existing workspace and makes the data-plane boundary clear.

## Prerequisites

1. Terraform >= 1.6, Google Cloud SDK, and a GCP project with billing.
2. A GCP Databricks workspace and a Unity Catalog metastore attached to it.
3. A Databricks personal access token (for a learning project) or service-principal OAuth credentials (recommended for CI).
4. The identity that runs the job must be able to read/write the GCS bucket. For production, create a Unity Catalog storage credential/external location and configure its name in `databricks_storage_credential_name`. Do not put a GCP JSON key in a notebook.

Each input file should contain one XML business record, for example:

```xml
<record><id>1001</id><name>Ada</name><email>ada@example.com</email><updated_at>2026-01-01T10:00:00Z</updated_at></record>
```

If your XML is an envelope such as `<records><record>...</record></records>`, adapt `row_tag` and the parser before using it; this compact example deliberately uses one record per file to retain each source document exactly in Bronze.

## Deploy dev

From `terraform/`, authenticate first:

```powershell
gcloud auth application-default login
$env:DATABRICKS_HOST = "https://<your-gcp-databricks-workspace-url>"
$env:DATABRICKS_TOKEN = "<token>"
terraform init -backend-config=environments/dev.backend.hcl
terraform apply -var-file=environments/dev.tfvars -var="gcp_project_id=<project-id>" -var="databricks_host=$env:DATABRICKS_HOST"
```

Terraform prints `landing_uri`. Upload the sample files (or your ten XML files):

```powershell
gcloud storage cp ../sample-data/*.xml gs://<bucket>/landing/
```

For a single repeatable command from the repository root, use the deployment
script. It accepts the state bucket explicitly so the same code can target
separate dev and prod Terraform states:

```powershell
$env:DATABRICKS_HOST = "https://<your-gcp-databricks-workspace-url>"
$env:DATABRICKS_TOKEN = "<token>"
./scripts/deploy.ps1 `
    -Environment dev `
    -GcpProjectId <gcp-project-id> `
    -TerraformStateBucket <dev-state-bucket> `
    -DatabricksHost $env:DATABRICKS_HOST `
    -Apply `
    -UploadSampleData
```

Run this first without `-DatabricksStorageCredentialName`. Terraform creates
the GCP bucket and service account. Then create the Unity Catalog credential
for the output service account, and run the same command again with
`-DatabricksStorageCredentialName <credential-name>`.

The state bucket must already exist. The Unity Catalog credential must be
approved for the workspace before the scheduled job can access the landing
bucket.

Run the workflow once from the Databricks UI, or with `databricks jobs run-now --job-id <job-id>`. It subsequently runs each day at 19:00.

## Promote the same code to prod

Use a distinct Terraform state and variable file. No code changes are needed:

```powershell
terraform init -reconfigure -backend-config="bucket=<prod-state-bucket>" -backend-config="prefix=xml-lakehouse/prod"
terraform apply -var-file=environments/prod.tfvars -var="gcp_project_id=<project-id>" -var="databricks_host=$env:DATABRICKS_HOST" -var="databricks_storage_credential_name=<uc-gcs-credential>"
```

The `environment` variable names buckets, schemas, job, and notebook directory separately, preventing dev/prod collisions. Store each environment's backend bucket and Databricks credentials in your CI secret store.

### One-time Databricks-to-GCS connection

After the first apply, Terraform outputs a Google service-account email. A Unity Catalog administrator should configure a GCS storage credential for that service account and set `databricks_storage_credential_name` in the environment `.tfvars`. On the next apply Terraform creates the environment-specific external location. This avoids service-account keys in Terraform state or notebooks. Grant the workflow's run-as identity `READ FILES` and `WRITE FILES` on that external location, plus `USE CATALOG`, `USE SCHEMA`, and table privileges on the two schemas.

## Verify

In Databricks SQL:

```sql
SELECT * FROM main.bronze_dev.xml_raw;
SELECT * FROM main.silver_dev.xml_records;
SELECT * FROM main.silver_dev.xml_quarantine;
```

The first run ingests all landing files. Later runs only ingest new files because Auto Loader tracks progress in GCS checkpoint storage. Replacing a file with the same path is intentionally not treated as a new event; use a new object name.

### Test the pipeline end-to-end

1. Run `terraform plan` and `terraform apply` for `dev`. Terraform must finish without errors and output a `landing_uri` and `databricks_job_id`.
2. Upload the ten files in `sample-data/` to the printed landing URI.
3. In Databricks, open **Workflows → xml-lakehouse-dev → Run now**. Confirm `bronze_ingest` and then `silver_transform` are green in the run details.
4. Run [tests/validation.sql](tests/validation.sql) in Databricks SQL. The expected result is 10 Bronze documents, 9 Silver records, zero quarantined records, and `Ada Lovelace` for ID `1001`.
5. To test a failure path, upload a uniquely named XML file with a blank `<name></name>`. Run the job again. The document remains in Bronze and appears in `silver_dev.xml_quarantine`; it must not be added to the Silver records table.

For a Terraform-only preflight use `terraform fmt -check -recursive` and `terraform validate` from the `terraform/` directory. `terraform plan` is the final infrastructure check because it verifies your real GCP and Databricks permissions.

## Project layout

- `terraform/`: repeatable GCP, namespace, notebook, and job deployment
- `databricks/notebooks/`: Bronze and Silver PySpark tasks
- `sample-data/`: ten sample XML source files

## Production notes

- Supply a policy-compliant job cluster in `job_cluster_policy_id` where required; the default is a small serverless-compatible cluster definition for learning.
- Set `databricks_catalog` to an existing governed catalog if your team does not allow catalog creation.
- Keep expected business fields in `required_columns`; records missing values are retained in Bronze and written to Silver quarantine.
- Terraform state has infrastructure metadata, not data. Protect it and use separate remote-state buckets for dev/prod.
