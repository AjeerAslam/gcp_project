variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "region" {
  type        = string
  description = "Google Cloud region for the landing bucket."
}

variable "environment" {
  type        = string
  description = "Environment name used in resource names and labels."
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for the bucket name."
  default     = "xml-lakehouse"
}

