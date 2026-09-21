locals {
  environment = terraform.workspace
}

module "landing" {
  source = "./modules/gcs_landing"

  project_id  = var.gcp_project_id
  region      = var.gcp_region
  environment = local.environment
}

module "pipeline" {
  source = "./modules/databricks_pipeline"

  catalog              = var.databricks_catalog
  environment          = local.environment
  landing_uri          = module.landing.landing_uri
  notebook_path        = "/Shared/xml-lakehouse/${local.environment}"
  notebook_source_root = "${path.root}/databricks"
}