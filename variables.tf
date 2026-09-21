variable "gcp_project_id" {
  type        = string
  description = "Google Cloud project ID for the selected workspace."
}

variable "gcp_region" {
  type        = string
  description = "Google Cloud region for the landing bucket."
  default     = "asia-south1"
}

variable "databricks_host" {
  type        = string
  description = "Databricks workspace URL for the selected workspace."
  sensitive   = true
}

variable "databricks_catalog" {
  type        = string
  description = "Unity Catalog catalog for the pipeline tables."
  default     = "workspace"
}

variable "databricks_run_as" {
  type        = string
  description = "Databricks user that runs the pipeline and receives external-location access."
  default     = "ajeeraslam@gmail.com"
}
