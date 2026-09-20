# Databricks notebook source
# MAGIC %md
# MAGIC ### Silver: infer XML schema, validate, clean, and de-duplicate
# MAGIC This example expects one `<record>...</record>` XML document per file.
# MAGIC The inferred schema is deliberately calculated from Bronze, so a new
# MAGIC source field can be added without a Terraform edit. Required fields are
# MAGIC a contract and records which violate it go to a quarantine Delta table.

# COMMAND ----------

from functools import reduce
from pyspark.sql import functions as F
from pyspark.sql.window import Window

dbutils.widgets.text("catalog", "main")
dbutils.widgets.text("bronze_schema", "bronze_dev")
dbutils.widgets.text("silver_schema", "silver_dev")
dbutils.widgets.text("required_columns", "id,name")

catalog = dbutils.widgets.get("catalog")
bronze_schema = dbutils.widgets.get("bronze_schema")
silver_schema = dbutils.widgets.get("silver_schema")
required_columns = [x.strip() for x in dbutils.widgets.get("required_columns").split(",") if x.strip()]

bronze_table = f"{catalog}.{bronze_schema}.xml_raw"
silver_table = f"{catalog}.{silver_schema}.xml_records"
quarantine_table = f"{catalog}.{silver_schema}.xml_quarantine"

bronze = spark.table(bronze_table)
if bronze.limit(1).count() == 0:
    print("Bronze is empty; no Silver work to perform.")
    dbutils.notebook.exit("EMPTY_BRONZE")

# Ask Spark to infer a DDL schema from the current raw XML. from_xml then parses
# every Bronze payload against it. All source columns are retained dynamically.
sample_xml = bronze.select("raw_xml").where(F.col("raw_xml").isNotNull()).first()["raw_xml"]
schema_ddl = spark.range(1).select(F.schema_of_xml(F.lit(sample_xml)).alias("ddl")).first()["ddl"]
parsed = bronze.select(
    F.from_xml(
        F.col("raw_xml"),
        schema_ddl,
        {"rowTag": "record", "mode": "PERMISSIVE"},
    ).alias("record"),
    "raw_xml", "source_file", "ingested_at",
)

records = parsed.select("record.*", "raw_xml", "source_file", "ingested_at")
source_columns = [c for c in records.columns if c not in {"raw_xml", "source_file", "ingested_at"}]
missing_contract_columns = sorted(set(required_columns) - set(source_columns))
if missing_contract_columns:
    raise ValueError(f"XML schema validation failed: required columns absent: {missing_contract_columns}")

# Normalize empty strings to null before validating. This is the Silver null-handling rule.
for field in source_columns:
    records = records.withColumn(
        field,
        F.when(F.trim(F.col(field).cast("string")) == "", F.lit(None)).otherwise(F.col(field)),
    )

invalid_condition = reduce(
    lambda left, right: left | right,
    [F.col(column).isNull() for column in required_columns],
)

quarantine = (
    records.where(invalid_condition)
    .withColumn("validation_error", F.lit("required column is null or blank"))
    .withColumn("quarantined_at", F.current_timestamp())
)
valid = records.where(~invalid_condition)

# Keep the newest version for each business key. When supplied, updated_at is
# preferred; otherwise ingestion time is used. Source filename breaks ties.
latest_timestamp = F.col("ingested_at")
if "updated_at" in source_columns:
    latest_timestamp = F.coalesce(F.to_timestamp(F.col("updated_at")), F.col("ingested_at"))
window = Window.partitionBy("id").orderBy(latest_timestamp.desc(), F.col("source_file").desc())
deduplicated = valid.withColumn("_row_number", F.row_number().over(window)).where("_row_number = 1").drop("_row_number")

quarantine.write.format("delta").mode("append").option("mergeSchema", "true").saveAsTable(quarantine_table)

# MERGE makes the pipeline idempotent: re-running the job updates the same ID,
# while dynamic schema evolution adds newly discovered source columns.
deduplicated.createOrReplaceTempView("silver_updates")
spark.sql(f"CREATE TABLE IF NOT EXISTS {silver_table} USING DELTA AS SELECT * FROM silver_updates WHERE 1 = 0")
columns = deduplicated.columns
update_clause = ", ".join([f"target.`{c}` = source.`{c}`" for c in columns])
insert_columns = ", ".join([f"`{c}`" for c in columns])
insert_values = ", ".join([f"source.`{c}`" for c in columns])
spark.sql(f"""
  MERGE WITH SCHEMA EVOLUTION INTO {silver_table} AS target
  USING silver_updates AS source
  ON target.id = source.id
  WHEN MATCHED THEN UPDATE SET {update_clause}
  WHEN NOT MATCHED THEN INSERT ({insert_columns}) VALUES ({insert_values})
""")

print(f"Silver transformation complete: {silver_table}")
