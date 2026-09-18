locals {
  resource_name = "${var.name_prefix}-${var.environment}"
  bucket_name   = "${local.resource_name}-${var.gcp_project_id}"
  bronze_schema_name = "bronze_${var.environment}"
  silver_schema_name = "silver_${var.environment}"
}

resource "google_storage_bucket" "lakehouse" {
  name                        = local.bucket_name
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning { enabled = true }

  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 90 }
  }

  labels = {
    environment = var.environment
    purpose     = "xml-lakehouse"
    managed_by  = "terraform"
  }
}

resource "google_service_account" "databricks_data" {
  account_id   = "xml-lake-${var.environment}"
  display_name = "Databricks XML lakehouse (${var.environment})"
}

resource "google_storage_bucket_iam_member" "databricks_data" {
  bucket = google_storage_bucket.lakehouse.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.databricks_data.email}"
}

# The catalog can be managed centrally. Schemas are isolated per environment.
resource "databricks_catalog" "lakehouse" {
  count = var.create_catalog ? 1 : 0
  name  = var.databricks_catalog
}

resource "databricks_schema" "bronze" {
  catalog_name = var.databricks_catalog
  name         = local.bronze_schema_name
  comment      = "Raw XML zone created by Terraform for ${var.environment}."
  depends_on   = [databricks_catalog.lakehouse]
}

resource "databricks_schema" "silver" {
  catalog_name = var.databricks_catalog
  name         = local.silver_schema_name
  comment      = "Validated XML zone created by Terraform for ${var.environment}."
  depends_on   = [databricks_catalog.lakehouse]
}
