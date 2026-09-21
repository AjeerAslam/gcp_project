output "environment" {
  description = "Currently selected Terraform workspace."
  value       = terraform.workspace
}

output "landing_uri" {
  description = "GCS path where XML files should be uploaded."
  value       = module.landing.landing_uri
}

output "bucket_name" {
  description = "GCS lakehouse bucket name."
  value       = module.landing.bucket_name
}

output "job_id" {
  description = "Databricks pipeline job ID."
  value       = module.pipeline.job_id
}

output "bronze_table" {
  description = "Fully qualified Bronze table name."
  value       = module.pipeline.bronze_table
}

output "silver_table" {
  description = "Fully qualified Silver table name."
  value       = module.pipeline.silver_table
}