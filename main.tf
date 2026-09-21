# Root module: connects the reusable infrastructure modules for the selected workspace.
locals {
  environment = terraform.workspace
}

module "landing" {
  source = "./modules/gcs_landing"

  project_id  = var.gcp_project_id
  region      = var.gcp_region
  environment = local.environment
}

module "storage_access" {
  # Connects the GCS landing bucket to Unity Catalog.
  source = "./modules/databricks_storage_access"

  bucket_name = module.landing.bucket_name
  landing_uri = module.landing.landing_uri
  environment = local.environment
  run_as_user = var.databricks_run_as
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
