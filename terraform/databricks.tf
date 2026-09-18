locals {
  notebook_root = "/Shared/xml-lakehouse/${var.environment}"
  landing_uri   = "gs://${google_storage_bucket.lakehouse.name}/landing"
  checkpoint_uri = "gs://${google_storage_bucket.lakehouse.name}/checkpoint"
  bad_records_uri = "gs://${google_storage_bucket.lakehouse.name}/bad-records"
}

resource "databricks_directory" "project" {
  path = local.notebook_root
}

resource "databricks_workspace_file" "bronze_notebook" {
  source = "${path.module}/../databricks/notebooks/01_bronze_ingest.py"
  path   = "${local.notebook_root}/01_bronze_ingest.py"
  depends_on = [databricks_directory.project]
}

resource "databricks_workspace_file" "silver_notebook" {
  source = "${path.module}/../databricks/notebooks/02_silver_transform.py"
  path   = "${local.notebook_root}/02_silver_transform.py"
  depends_on = [databricks_directory.project]
}

# Credential creation is often owned by Databricks account administrators. This
# resource connects the environment bucket to an already approved credential.
resource "databricks_external_location" "lakehouse" {
  count           = var.databricks_storage_credential_name == null ? 0 : 1
  name            = "xml_lakehouse_${var.environment}"
  url             = "gs://${google_storage_bucket.lakehouse.name}"
  credential_name = var.databricks_storage_credential_name
  comment         = "GCS XML lakehouse location for ${var.environment}"
}

resource "databricks_job" "xml_pipeline" {
  name                = "xml-lakehouse-${var.environment}"
  max_concurrent_runs = 1
  depends_on = [databricks_external_location.lakehouse]

  schedule {
    quartz_cron_expression = "0 0 19 * * ?"
    timezone_id            = var.schedule_timezone
    pause_status           = "UNPAUSED"
  }

  job_cluster {
    job_cluster_key = "xml_pipeline_cluster"
    new_cluster {
      spark_version       = "15.4.x-scala2.12"
      node_type_id        = "n2-standard-4"
      num_workers         = 1
      policy_id           = var.job_cluster_policy_id
      data_security_mode  = "USER_ISOLATION"
      custom_tags = {
        environment = var.environment
        project     = "xml-lakehouse"
      }
    }
  }

  task {
    task_key        = "bronze_ingest"
    job_cluster_key = "xml_pipeline_cluster"
    notebook_task {
      notebook_path = databricks_workspace_file.bronze_notebook.path
      base_parameters = {
        landing_uri     = local.landing_uri
        checkpoint_uri  = local.checkpoint_uri
        catalog         = var.databricks_catalog
        bronze_schema   = databricks_schema.bronze.name
        silver_schema   = databricks_schema.silver.name
      }
    }
  }

  task {
    task_key        = "silver_transform"
    depends_on { task_key = "bronze_ingest" }
    job_cluster_key = "xml_pipeline_cluster"
    notebook_task {
      notebook_path = databricks_workspace_file.silver_notebook.path
      base_parameters = {
        catalog          = var.databricks_catalog
        bronze_schema    = databricks_schema.bronze.name
        silver_schema    = databricks_schema.silver.name
        required_columns = join(",", var.required_columns)
      }
    }
  }
}
