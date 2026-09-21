terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    databricks = {
      source = "databricks/databricks"
    }
  }
}

locals {
  service_account_email = databricks_storage_credential.gcs.databricks_gcp_service_account[0].email
}

resource "databricks_storage_credential" "gcs" {
  name = "xml-lakehouse-${var.environment}-gcs"

  databricks_gcp_service_account {}
}


resource "databricks_external_location" "gcs_landing" {
  name            = "xml-lakehouse-${var.environment}-landing"
  url             = var.landing_uri
  credential_name = databricks_storage_credential.gcs.name
  skip_validation = true

  depends_on = [
    google_storage_bucket_iam_member.object_viewer,
    google_storage_bucket_iam_member.bucket_reader,
  ]
}

resource "databricks_grants" "gcs_landing" {
  external_location = databricks_external_location.gcs_landing.name

  grant {
    principal  = var.run_as_user
    privileges = ["READ_FILES"]
  }
}

resource "google_storage_bucket_iam_member" "object_viewer" {
  bucket = var.bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.service_account_email}"
}

resource "google_storage_bucket_iam_member" "bucket_reader" {
  bucket = var.bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${local.service_account_email}"
}