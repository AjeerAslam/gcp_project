provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Authentication comes from DATABRICKS_TOKEN (local learning) or the standard
# Databricks OAuth environment variables (CI). Never commit credentials here.
provider "databricks" {
  host = var.databricks_host
}
