locals {
  environment = terraform.workspace
}

module "landing" {
  source = "./modules/gcs_landing"

  project_id  = var.gcp_project_id
  region      = var.gcp_region
  environment = local.environment
}

resource "databricks_storage_credential" "gcs" {
  name    = "xml-lakehouse-${local.environment}-gcs"
  comment = "GCS access for the ${local.environment} XML lakehouse."

  databricks_gcp_service_account {}
}

resource "google_storage_bucket_iam_member" "databricks_uc" {
  bucket = module.landing.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${databricks_storage_credential.gcs.databricks_gcp_service_account[0].email}"
}

resource "google_storage_bucket_iam_member" "databricks_uc_bucket_reader" {
  bucket = module.landing.bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${databricks_storage_credential.gcs.databricks_gcp_service_account[0].email}"
}

resource "databricks_external_location" "gcs_landing" {
  name            = "xml-lakehouse-${local.environment}-landing"
  url             = module.landing.landing_uri
  credential_name = databricks_storage_credential.gcs.name
  comment         = "GCS landing path for the ${local.environment} XML lakehouse."

  depends_on = [google_storage_bucket_iam_member.databricks_uc]
}

resource "databricks_grants" "gcs_landing" {
  external_location = databricks_external_location.gcs_landing.name

  grant {
    principal  = var.databricks_run_as
    privileges = ["READ_FILES"]
  }
}

module "pipeline" {
  source = "./modules/databricks_pipeline"

  catalog              = var.databricks_catalog
  environment          = local.environment
  landing_uri          = module.landing.landing_uri
  notebook_path        = "/Shared/xml-lakehouse/${local.environment}"
  notebook_source_root = "${path.root}/databricks"
  run_as_user          = var.databricks_run_as
}