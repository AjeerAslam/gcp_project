output "job_id" {
  description = "Databricks pipeline job ID."
  value       = databricks_job.pipeline.id
}

output "bronze_table" {
  description = "Fully qualified Bronze table name."
  value       = "${var.catalog}.${databricks_schema.bronze.name}.xml_raw"
}

output "silver_table" {
  description = "Fully qualified Silver table name."
  value       = "${var.catalog}.${databricks_schema.silver.name}.customers"
}