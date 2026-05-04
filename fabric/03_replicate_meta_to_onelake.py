# Notebook: 03_replicate_meta_to_onelake.py  (Fabric PySpark notebook)
#
# Replicates the canonical meta.* tables from the Azure SQL DB into a
# dedicated Fabric Lakehouse ("lh_metadata") as Delta tables.  This Lakehouse
# is the NEW propagation hub: every downstream consumer (Lakehouse comments,
# Warehouse, Direct Lake semantic model, Purview push, Copilot grounding,
# Fabric Data Agents) reads from here — NOT from sys.extended_properties.
#
# Why this design:
#   * Zero DDL writes on the source OLTP database (no sp_addextendedproperty).
#   * Survives DROP/CREATE of source views/procs (level-2 extended properties
#     would otherwise be lost on every redeploy).
#   * Versioned in Delta time-travel for free → drift audit & rollback.
#   * Co-locates metadata with data in OneLake for fast Spark/SQL/Copilot
#     reads without crossing back to the source DB.
#
# Source-of-truth flow:
#   view/proc headers in Git  →  meta.* in Azure SQL DB  →  Delta in OneLake
#   (Author writes header. CI runs extractor. This notebook mirrors out.)
# ---------------------------------------------------------------------------
from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, lit, sha2, concat_ws, col
from delta.tables import DeltaTable

spark = SparkSession.builder.getOrCreate()

# ---- Config ---------------------------------------------------------------
SQL_SERVER       = "brookfield-sql.database.windows.net"
SQL_DATABASE     = "EnercareCore"
META_LAKEHOUSE   = "lh_metadata"      # dedicated Fabric Lakehouse
JDBC_URL = (
    f"jdbc:sqlserver://{SQL_SERVER}:1433;database={SQL_DATABASE};"
    "encrypt=true;trustServerCertificate=false;"
    "authentication=ActiveDirectoryMSI"
)

TABLES = [
    # (sql_object,                delta_target,                merge_keys)
    ("meta.AssetMetadata",        "asset_metadata",            ["SchemaName","ObjectName"]),
    ("meta.ColumnMetadata",       "column_metadata",           ["SchemaName","ObjectName","ColumnName"]),
    ("meta.KpiMetadata",          "kpi_metadata",              ["SchemaName","ObjectName","KpiName"]),
    ("meta.ParameterMetadata",    "parameter_metadata",        ["SchemaName","ObjectName","Direction","ParameterName"]),
    ("meta.vw_BusinessMetadata",  "vw_business_metadata",      None),     # view → full overwrite
]

# ---- Mirror loop ----------------------------------------------------------
for sql_obj, delta_target, keys in TABLES:
    src = (spark.read.format("jdbc")
                .option("url", JDBC_URL)
                .option("dbtable", sql_obj)
                .load()
                .withColumn("_replicated_at_utc", current_timestamp())
                .withColumn("_source", lit(f"{SQL_SERVER}/{SQL_DATABASE}/{sql_obj}")))

    # Add a row-level fingerprint so downstream propagators can do delta-only updates
    src = src.withColumn(
        "_row_hash",
        sha2(concat_ws("||", *[c for c in src.columns if not c.startswith("_")]), 256)
    )

    target_path = f"Tables/{delta_target}"
    full_name   = f"{META_LAKEHOUSE}.{delta_target}"

    if not spark.catalog.tableExists(full_name):
        (src.write.format("delta")
            .option("delta.columnMapping.mode", "name")
            .saveAsTable(full_name))
        print(f"created {full_name} ({src.count()} rows)")
        continue

    if keys is None:
        # No natural key (it's a view) → atomic overwrite
        (src.write.format("delta").mode("overwrite")
            .option("overwriteSchema", "true").saveAsTable(full_name))
        print(f"overwrote {full_name} ({src.count()} rows)")
        continue

    # MERGE upsert on natural keys
    target = DeltaTable.forName(spark, full_name)
    cond   = " AND ".join([f"t.{k} = s.{k}" for k in keys])
    (target.alias("t")
           .merge(src.alias("s"), cond)
           .whenMatchedUpdateAll(condition="t._row_hash <> s._row_hash")
           .whenNotMatchedInsertAll()
           .execute())
    print(f"merged {full_name}")

# ---- Surface a Lakehouse SQL endpoint view for Copilot grounding ----------
spark.sql(f"""
CREATE OR REPLACE VIEW {META_LAKEHOUSE}.vw_business_metadata_current AS
SELECT * FROM {META_LAKEHOUSE}.vw_business_metadata
WHERE  AssetIsDraft = 0 AND (ColumnIsDraft = 0 OR ColumnName IS NULL)
""")

print("Metadata Lakehouse refreshed.")
