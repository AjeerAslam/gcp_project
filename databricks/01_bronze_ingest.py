# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze: load XML from GCS
# MAGIC
# MAGIC This notebook stores each XML file as raw text.

# COMMAND ----------

from pyspark.sql.functions import col, current_timestamp, input_file_name

dbutils.widgets.text("landing_uri", "")
dbutils.widgets.text("checkpoint_uri", "")
dbutils.widgets.text("catalog", "workspace")
dbutils.widgets.text("bronze_schema", "bronze_dev")

landing_uri = dbutils.widgets.get("landing_uri").rstrip("/")
checkpoint_uri = dbutils.widgets.get("checkpoint_uri").rstrip("/")
catalog = dbutils.widgets.get("catalog")
bronze_schema = dbutils.widgets.get("bronze_schema")

if not landing_uri or not checkpoint_uri:
    raise ValueError("The GCS landing and checkpoint paths are required.")

bronze_table = f"{catalog}.{bronze_schema}.xml_raw"

raw_xml = (
    spark.readStream.format("cloudFiles")
    .option("cloudFiles.format", "text")
    .option("pathGlobFilter", "*.xml")
    .load(landing_uri)
    .select(
        col("value").alias("raw_xml"),
        input_file_name().alias("source_file"),
        current_timestamp().alias("ingested_at"),
    )
)

(
    raw_xml.writeStream.format("delta")
    .option("checkpointLocation", f"{checkpoint_uri}/bronze")
    .option("mergeSchema", "true")
    .trigger(availableNow=True)
    .toTable(bronze_table)
    .awaitTermination()
)

print(f"Bronze table ready: {bronze_table}")
