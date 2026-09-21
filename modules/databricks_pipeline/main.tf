terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

resource "databricks_schema" "bronze" {
  catalog_name = var.catalog
  name         = "bronze_${var.environment}"
  comment      = "Raw XML data for the ${var.environment} environment."
}

resource "databricks_schema" "silver" {
  catalog_name = var.catalog
  name         = "silver_${var.environment}"
  comment      = "Clean customer data for the ${var.environment} environment."
}

resource "databricks_directory" "notebooks" {
  path = var.notebook_path
}

resource "databricks_notebook" "bronze" {
  source     = "${var.notebook_source_root}/01_bronze_ingest.py"
  path       = "${var.notebook_path}/01_bronze_ingest"
  language   = "PYTHON"
  format     = "SOURCE"
  depends_on = [databricks_directory.notebooks]
}

resource "databricks_notebook" "silver" {
  source     = "${var.notebook_source_root}/02_silver_transform.py"
  path       = "${var.notebook_path}/02_silver_transform"
  language   = "PYTHON"
  format     = "SOURCE"
  depends_on = [databricks_directory.notebooks]
}

resource "databricks_job" "pipeline" {
  name                = "xml-lakehouse-${var.environment}"
  max_concurrent_runs = 1

  environment {
    environment_key = "pipeline_environment"

    spec {
      client = "1"
    }
  }

  task {
    task_key        = "bronze"
    environment_key = "pipeline_environment"

    notebook_task {
      notebook_path = databricks_notebook.bronze.path
      base_parameters = {
        landing_uri   = var.landing_uri
        catalog       = var.catalog
        bronze_schema = databricks_schema.bronze.name
      }
    }
  }

  task {
    task_key        = "silver"
    environment_key = "pipeline_environment"

    depends_on {
      task_key = "bronze"
    }

    notebook_task {
      notebook_path = databricks_notebook.silver.path
      base_parameters = {
        catalog       = var.catalog
        bronze_schema = databricks_schema.bronze.name
        silver_schema = databricks_schema.silver.name
      }
    }
  }
}