output "bucket_name" {
  description = "GCS landing bucket name."
  value       = google_storage_bucket.this.name
}

output "landing_uri" {
  description = "GCS path where source files should be uploaded."
  value       = "gs://${google_storage_bucket.this.name}/landing"
}

