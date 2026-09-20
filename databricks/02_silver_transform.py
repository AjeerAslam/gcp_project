# Databricks notebook source
# MAGIC %md
# MAGIC # Silver: parse and clean customers
# MAGIC
# MAGIC This notebook reads Bronze, parses the XML, and keeps the newest row for each customer.

# COMMAND ----------

from pyspark.sql import functions as F

dbutils.widgets.text("catalog", "workspace")
dbutils.widgets.text("bronze_schema", "bronze_dev")
dbutils.widgets.text("silver_schema", "silver_dev")

catalog = dbutils.widgets.get("catalog")
bronze_schema = dbutils.widgets.get("bronze_schema")
silver_schema = dbutils.widgets.get("silver_schema")

bronze_table = f"{catalog}.{bronze_schema}.xml_raw"
silver_table = f"{catalog}.{silver_schema}.customers"

bronze = spark.read.table(bronze_table)

customer_schema = "id STRING, name STRING, email STRING, updated_at TIMESTAMP"
customers = bronze.select(
    F.from_xml("raw_xml", customer_schema, {"rowTag": "record"}).alias("customer"),
    "source_file",
    "ingested_at",
).select("customer.*", "source_file", "ingested_at")

silver = customers.dropDuplicates(["id"])

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(silver_table)

print(f"Silver table ready: {silver_table}")
