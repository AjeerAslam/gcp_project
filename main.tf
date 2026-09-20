variable "gcp_project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "gcp_region" {
  type    = string
  default = "asia-south1"
}

variable "databricks_host" {
  type        = string
  description = "Databricks workspace URL."
  sensitive   = true
}

variable "databricks_catalog" {
  type    = string
  default = "workspace"
}

moved {
  from = google_service_account.databricks_data
  to   = google_service_account.databricks
}

moved {
  from = google_storage_bucket_iam_member.databricks_data
  to   = google_storage_bucket_iam_member.databricks
}

moved {
  from = databricks_directory.project
  to   = databricks_directory.notebooks
}

moved {
  from = databricks_workspace_file.bronze_notebook
  to   = databricks_workspace_file.bronze
}

moved {
  from = databricks_workspace_file.silver_notebook
  to   = databricks_workspace_file.silver
}

moved {
  from = databricks_job.xml_pipeline
  to   = databricks_job.pipeline
}

locals {
  bucket_name   = "xml-lakehouse-dev-${var.gcp_project_id}"
  notebook_path = "/Shared/xml-lakehouse/dev"
  landing_uri   = "gs://${local.bucket_name}/landing"
  checkpoint_uri = "gs://${local.bucket_name}/checkpoint"
}

resource "google_storage_bucket" "lakehouse" {
  name                        = local.bucket_name
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = false
  versioning { enabled = true }
}

resource "google_service_account" "databricks" {
  account_id   = "xml-lake-dev"
  display_name = "Databricks XML lakehouse dev"
}

resource "google_storage_bucket_iam_member" "databricks" {
  bucket = google_storage_bucket.lakehouse.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.databricks.email}"
}

resource "databricks_schema" "bronze" {
  catalog_name = var.databricks_catalog
  name         = "bronze_dev"
  comment      = "Raw XML data."
}

resource "databricks_schema" "silver" {
  catalog_name = var.databricks_catalog
  name         = "silver_dev"
  comment      = "Clean customer data."
}

resource "databricks_directory" "notebooks" {
  path = local.notebook_path
}

resource "databricks_workspace_file" "bronze" {
  source     = "${path.module}/databricks/01_bronze_ingest.py"
  path       = "${local.notebook_path}/01_bronze_ingest.py"
  depends_on = [databricks_directory.notebooks]
}

resource "databricks_workspace_file" "silver" {
  source     = "${path.module}/databricks/02_silver_transform.py"
  path       = "${local.notebook_path}/02_silver_transform.py"
  depends_on = [databricks_directory.notebooks]
}

resource "databricks_job" "pipeline" {
  name                = "xml-lakehouse-dev"
  max_concurrent_runs = 1

  environment {
    environment_key = "pipeline_environment"
    spec { client = "1" }
  }

  task {
    task_key        = "bronze"
    environment_key = "pipeline_environment"
    notebook_task {
      notebook_path = databricks_workspace_file.bronze.path
      base_parameters = {
        landing_uri    = local.landing_uri
        checkpoint_uri = local.checkpoint_uri
        catalog        = var.databricks_catalog
        bronze_schema  = databricks_schema.bronze.name
      }
    }
  }

  task {
    task_key        = "silver"
    environment_key = "pipeline_environment"
    depends_on { task_key = "bronze" }
    notebook_task {
      notebook_path = databricks_workspace_file.silver.path
      base_parameters = {
        catalog       = var.databricks_catalog
        bronze_schema = databricks_schema.bronze.name
        silver_schema = databricks_schema.silver.name
      }
    }
  }
}

output "landing_uri" {
  value = local.landing_uri
}

output "bucket_name" {
  value = google_storage_bucket.lakehouse.name
}

output "job_id" {
  value = databricks_job.pipeline.id
}
