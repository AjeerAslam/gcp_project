variable "gcp_project_id" {
  description = "Google Cloud project that owns the data bucket."
  type        = string
}

variable "gcp_region" {
  description = "GCP region for the bucket."
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "Deployment environment, for example dev or prod."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "name_prefix" {
  description = "Lowercase globally unique prefix for GCS resources."
  type        = string
  default     = "xml-lakehouse-demo"
}

variable "databricks_host" {
  description = "Existing GCP Databricks workspace URL."
  type        = string
  sensitive   = true
}

variable "databricks_catalog" {
  description = "Unity Catalog catalog to create/use."
  type        = string
  default     = "main"
}

variable "create_catalog" {
  description = "Create databricks_catalog. Set false if it is centrally managed."
  type        = bool
  default     = false
}

variable "job_cluster_policy_id" {
  description = "Optional policy ID required by your Databricks workspace."
  type        = string
  default     = null
}

variable "databricks_storage_credential_name" {
  description = "Existing Unity Catalog GCS storage credential. When set, Terraform also registers the bucket as an external location."
  type        = string
  default     = null
}

variable "schedule_timezone" {
  description = "IANA timezone for the daily job schedule."
  type        = string
  default     = "Asia/Kolkata"
}

variable "required_columns" {
  description = "Fields required in parsed XML records."
  type        = list(string)
  default     = ["id", "name"]
}
