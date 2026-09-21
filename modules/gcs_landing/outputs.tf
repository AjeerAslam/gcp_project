output "bucket_name" {
  description = "GCS landing bucket name."
  value       = google_storage_bucket.this.name
}

output "landing_uri" {
  description = "GCS path where source files should be uploaded."
  value       = "gs://${google_storage_bucket.this.name}/landing"
}

output "service_account_email" {
  description = "Service account used by the Databricks integration."
  value       = google_service_account.databricks.email
}