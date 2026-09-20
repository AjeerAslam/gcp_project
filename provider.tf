terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.60"
    }
  }

  backend "gcs" {
    bucket = "project-b142c40e-70d4-4124-9ee-xml-tfstate"
    prefix = "xml-lakehouse/dev"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "databricks" {
  host = var.databricks_host
}
