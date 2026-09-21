# Storage access inputs: identify the bucket, path, environment, and Databricks user.
variable "bucket_name" {
  type        = string
  description = "GCS bucket receiving the XML landing files."
}

variable "landing_uri" {
  type        = string
  description = "GCS URI registered as the Unity Catalog external location."
}

variable "environment" {
  type        = string
  description = "Environment name used in Unity Catalog object names."
}

variable "run_as_user" {
  type        = string
  description = "Databricks user granted READ_FILES on the external location."
}