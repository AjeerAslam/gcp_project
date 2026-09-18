# Databricks notebook source
# MAGIC %md
# MAGIC ### Bronze: preserve source XML exactly
# MAGIC This task uses Auto Loader to record each new XML document as text. No
# MAGIC business parsing occurs in Bronze; `raw_xml` can always be replayed.

# COMMAND ----------

from pyspark.sql.functions import col, current_timestamp, input_file_name

dbutils.widgets.text("landing_uri", "")
dbutils.widgets.text("checkpoint_uri", "")
dbutils.widgets.text("catalog", "main")
dbutils.widgets.text("bronze_schema", "bronze_dev")
dbutils.widgets.text("silver_schema", "silver_dev")

landing_uri = dbutils.widgets.get("landing_uri").rstrip("/")
checkpoint_uri = dbutils.widgets.get("checkpoint_uri").rstrip("/")
catalog = dbutils.widgets.get("catalog")
bronze_schema = dbutils.widgets.get("bronze_schema")

if not landing_uri or not checkpoint_uri:
    raise ValueError("landing_uri and checkpoint_uri must be provided by the job.")

bronze_table = f"{catalog}.{bronze_schema}.xml_raw"
checkpoint = f"{checkpoint_uri}/bronze_xml_raw"

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
    .option("checkpointLocation", checkpoint)
    .option("mergeSchema", "true")
    .trigger(availableNow=True)
    .toTable(bronze_table)
    .awaitTermination()
)

print(f"Bronze ingestion complete: {bronze_table}")
