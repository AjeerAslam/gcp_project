output "landing_uri" { value = local.landing_uri }
output "bucket_name" { value = google_storage_bucket.lakehouse.name }
output "databricks_job_id" { value = databricks_job.xml_pipeline.id }
output "databricks_service_account" { value = google_service_account.databricks_data.email }
