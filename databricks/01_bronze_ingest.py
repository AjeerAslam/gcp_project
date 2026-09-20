# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze: load XML from GCS
# MAGIC
# MAGIC This notebook stores each XML file as raw text.

# COMMAND ----------

from pyspark.sql.functions import col, current_timestamp, input_file_name

dbutils.widgets.text("landing_uri", "")
dbutils.widgets.text("catalog", "workspace")
dbutils.widgets.text("bronze_schema", "bronze_dev")

landing_uri = dbutils.widgets.get("landing_uri").rstrip("/")
catalog = dbutils.widgets.get("catalog")
bronze_schema = dbutils.widgets.get("bronze_schema")

if not landing_uri:
    raise ValueError("The GCS landing path is required.")

bronze_table = f"{catalog}.{bronze_schema}.xml_raw"

raw_xml = (
    spark.read.format("text")
    .option("pathGlobFilter", "*.xml")
    .load(landing_uri)
    .select(
        col("value").alias("raw_xml"),
        input_file_name().alias("source_file"),
        current_timestamp().alias("ingested_at"),
    )
)

raw_xml.write.format("delta").mode("overwrite").saveAsTable(bronze_table)

print(f"Bronze table ready: {bronze_table}")
