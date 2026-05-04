# Notebook: 05_apply_metadata_to_fabric.py  (run as a PySpark notebook in Fabric)
#
# Reads the OneLake metadata Lakehouse (lh_metadata.vw_business_metadata_current,
# refreshed by 03_replicate_meta_to_onelake.py) and propagates the metadata
# to three Fabric surfaces:
#
#   1. Lakehouse Delta tables   -> column COMMENTs (Spark SQL)
#   2. Fabric Warehouse copies  -> sp_addextendedproperty *on the WAREHOUSE only*
#                                  (Fabric Warehouse XPs are local to Fabric;
#                                   we do NOT write back to the source SQL DB)
#   3. Direct Lake Semantic Model -> table/column/measure descriptions
#                                    via TOM (Microsoft.AnalysisServices.Tabular)
#                                    over the workspace XMLA endpoint
#
# Why this script no longer touches sys.extended_properties on the source:
#   The propagation hub moved to OneLake (lh_metadata). All consumers below
#   read from there. The source OLTP database is read-only for this pipeline.
# ---------------------------------------------------------------------------
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lower, when
import pyodbc, os, json, sys, subprocess

spark = SparkSession.builder.getOrCreate()

# ---- Config ---------------------------------------------------------------
META_LAKEHOUSE      = "lh_metadata"
LAKEHOUSE_NAME      = "lh_enercare_silver"
WAREHOUSE_CONN_STR  = (   # Fabric Warehouse connection string (T-SQL endpoint)
    "Driver={ODBC Driver 18 for SQL Server};"
    "Server=<workspace>-<warehouse>.datawarehouse.fabric.microsoft.com;"
    "Database=wh_enercare_gold;"
    "Authentication=ActiveDirectoryInteractive;Encrypt=yes;"
)
SEMANTIC_MODEL      = "sm_enercare_customer360"
WORKSPACE_XMLA      = (   # Power BI / Fabric workspace XMLA endpoint
    "powerbi://api.powerbi.com/v1.0/myorg/Brookfield%20Enercare%20Analytics"
)

# ---- 1. Read the unified metadata from the OneLake metadata Lakehouse -----
meta_df = (
    spark.read.table(f"{META_LAKEHOUSE}.vw_business_metadata_current")
         .cache()
)
meta_df.createOrReplaceTempView("vw_business_metadata")

# ---------------------------------------------------------------------------
# 2. Apply column comments to Lakehouse Delta tables
#    Mirrored Azure SQL DB tables show up under the mirrored DB workspace as
#    Delta. We can attach them as shortcuts inside the Lakehouse and ALTER
#    them from there. Object names are case-insensitive in Spark SQL but the
#    Delta column metadata is preserved verbatim.
# ---------------------------------------------------------------------------
def safe_comment(s: str) -> str:
    return (s or "").replace("'", "''")

lh_tables = (
    spark.sql(f"SHOW TABLES IN {LAKEHOUSE_NAME}")
         .selectExpr("tableName")
         .rdd.map(lambda r: r.tableName.lower())
         .collect()
)

# Per-asset table comment
asset_rows = (meta_df
    .select("SchemaName", "ObjectName", "AssetDescription")
    .where("AssetDescription IS NOT NULL")
    .dropDuplicates(["SchemaName", "ObjectName"])
    .collect())

for r in asset_rows:
    qname = r["ObjectName"].lower()                       # mirrored tables flatten schema by default
    if qname not in lh_tables:
        continue
    cmt = safe_comment(r["AssetDescription"])
    spark.sql(f"ALTER TABLE {LAKEHOUSE_NAME}.{qname} SET TBLPROPERTIES ('comment' = '{cmt}')")

# Per-column comments
col_rows = (meta_df
    .where("ColumnName IS NOT NULL AND ColumnDescription IS NOT NULL")
    .select("ObjectName", "ColumnName", "DataType", "ColumnDescription")
    .collect())

for r in col_rows:
    tname = r["ObjectName"].lower()
    if tname not in lh_tables:
        continue
    cmt = safe_comment(r["ColumnDescription"])
    # ALTER COLUMN ... COMMENT requires Delta Lake >= 1.0 (Fabric default)
    spark.sql(
        f"ALTER TABLE {LAKEHOUSE_NAME}.{tname} "
        f"ALTER COLUMN {r['ColumnName']} COMMENT '{cmt}'"
    )

print(f"Applied Delta column comments to {len(col_rows)} columns "
      f"and {len(asset_rows)} table comments.")

# ---------------------------------------------------------------------------
# 3. Apply extended properties to Fabric Warehouse copies (Gold layer)
# ---------------------------------------------------------------------------
def apply_to_warehouse(df):
    with pyodbc.connect(WAREHOUSE_CONN_STR) as cn:
        cur = cn.cursor()
        for r in df.where("ColumnName IS NOT NULL AND ColumnDescription IS NOT NULL").collect():
            try:
                # Existence check first to avoid sp_addextendedproperty failure
                cur.execute("""
                    DECLARE @exists BIT = 0;
                    IF EXISTS (
                        SELECT 1
                        FROM sys.extended_properties ep
                        JOIN sys.objects o   ON o.object_id = ep.major_id
                        JOIN sys.schemas sc  ON sc.schema_id = o.schema_id
                        JOIN sys.columns c   ON c.object_id = o.object_id AND c.column_id = ep.minor_id
                        WHERE ep.name='MS_Description' AND sc.name=? AND o.name=? AND c.name=?)
                       SET @exists = 1;
                    SELECT @exists;""",
                    r["SchemaName"], r["ObjectName"], r["ColumnName"])
                exists = cur.fetchone()[0] == 1
                proc = "sp_updateextendedproperty" if exists else "sp_addextendedproperty"
                cur.execute(
                    f"EXEC {proc} @name=N'MS_Description', @value=?, "
                    "@level0type=N'SCHEMA', @level0name=?, "
                    "@level1type=N'TABLE',  @level1name=?, "
                    "@level2type=N'COLUMN', @level2name=?",
                    r["ColumnDescription"], r["SchemaName"], r["ObjectName"], r["ColumnName"])
            except Exception as e:
                print(f"WARN warehouse XP failed for "
                      f"{r['SchemaName']}.{r['ObjectName']}.{r['ColumnName']}: {e}")
        cn.commit()

apply_to_warehouse(meta_df)

# ---------------------------------------------------------------------------
# 4. Push descriptions to the Direct Lake Semantic Model via TOM
#    Requires Microsoft.AnalysisServices.Tabular (preinstalled in Fabric Spark
#    via the .NET interop bridge). For environments without it, fall back to
#    sempy.fabric or the REST 'updateDataset' API.
# ---------------------------------------------------------------------------
try:
    import sempy.fabric as fabric          # Fabric semantic-link library
    tom = fabric.create_tom_server(workspace="Brookfield Enercare Analytics")
    db  = tom.Databases[SEMANTIC_MODEL]
    model = db.Model

    # Pre-index rows by (table, column) for O(1) lookup
    asset_idx = {(r["SchemaName"], r["ObjectName"]): r for r in asset_rows}
    col_idx   = {(r["ObjectName"].lower(), r["ColumnName"].lower()): r for r in col_rows}

    for tbl in model.Tables:
        # find an asset row whose ObjectName matches the model table name
        for (s,o), r in asset_idx.items():
            if o.lower() == tbl.Name.lower():
                tbl.Description = r["AssetDescription"] or tbl.Description
                break

        for col_obj in tbl.Columns:
            r = col_idx.get((tbl.Name.lower(), col_obj.Name.lower()))
            if r and r["ColumnDescription"]:
                col_obj.Description = r["ColumnDescription"]

        # Push KPI-derived measures created elsewhere; descriptions only
        for m in tbl.Measures:
            r = col_idx.get((tbl.Name.lower(), m.Name.lower()))
            if r and r["ColumnDescription"]:
                m.Description = r["ColumnDescription"]

    model.SaveChanges()
    print(f"Semantic model '{SEMANTIC_MODEL}' descriptions saved.")
except ImportError:
    print("sempy not available in this kernel; rerun in a Fabric notebook.")
