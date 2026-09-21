terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

locals {
  bucket_name = "${var.name_prefix}-${var.environment}-${var.project_id}"
}

resource "google_storage_bucket" "this" {
  name                        = local.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    purpose     = "xml-lakehouse"
    managed_by  = "terraform"
  }
}

resource "google_service_account" "databricks" {
  account_id   = "xml-lake-${var.environment}"
  display_name = "Databricks XML lakehouse ${var.environment}"
}

resource "google_storage_bucket_iam_member" "databricks" {
  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.databricks.email}"
}