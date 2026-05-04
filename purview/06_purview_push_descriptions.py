"""
06_purview_push_descriptions.py
Pushes column- and asset-level descriptions from the OneLake metadata
Lakehouse (lh_metadata.vw_business_metadata_current) into Microsoft Purview
Unified Catalog using the Atlas REST API (pyapacheatlas).

Adapted from the public reference scripts:
  https://www.thoughtreplica.com/post/automate-sql-column-metadata-in-microsoft-purview
  https://github.com/stvflowers/Microsoft-Purview-Automation/tree/main/Samples/Azure%20SQL%20Column%20Descriptions

Differences vs. the references:
  * The references read from sys.extended_properties (MS_Description). We do
    NOT write to or read from sys.extended_properties at all. Authoritative
    descriptions come from view/proc headers, materialized in OneLake.
  * Pushes to BOTH the Azure SQL source asset (`mssql_column`) AND its
    Fabric Lakehouse counterpart (`fabric_lakehouse_table_column`) and the
    Direct Lake semantic model column (`powerbi_dataset_column`). This is
    what gives Brookfield the "single, unified catalog" outcome.
  * Uses Atlas glossary term assignment when @glossary tags are present.

Run mode:
  - Inside Fabric (PySpark notebook): reads lh_metadata directly via Spark.
  - Outside Fabric (CI runner): falls back to the SQL endpoint of the
    metadata Lakehouse via pyodbc. Configure either USE_SPARK=1 or
    METADATA_SQL_ENDPOINT.
"""
import os, json, logging
from pyapacheatlas.auth   import ServicePrincipalAuthentication
from pyapacheatlas.core   import PurviewClient
from pyapacheatlas.core.glossary import GlossaryClient

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
log = logging.getLogger("purview-push")

# ---- Auth -----------------------------------------------------------------
auth = ServicePrincipalAuthentication(
    tenant_id     = os.environ["AZURE_TENANT_ID"],
    client_id     = os.environ["AZURE_CLIENT_ID"],
    client_secret = os.environ["AZURE_CLIENT_SECRET"],
)
client   = PurviewClient(account_name=os.environ["PURVIEW_NAME"], authentication=auth)
glossary = GlossaryClient(client)

# ---- Read metadata from OneLake (preferred) or its SQL endpoint -----------
ROW_QUERY = """
SELECT ServerName, DatabaseName, SchemaName, ObjectName, AssetType,
       AssetDescription, AssetGlossaryTerms,
       ColumnName, ColumnDescription, ColumnGlossaryTerms,
       PurviewQualifiedName
FROM   vw_business_metadata_current
"""

def read_rows():
    """Yield dict rows from the OneLake metadata Lakehouse."""
    if os.environ.get("USE_SPARK") == "1":
        from pyspark.sql import SparkSession
        spark = SparkSession.builder.getOrCreate()
        df = spark.sql(f"USE lh_metadata; { ROW_QUERY }")
        for r in df.collect():
            yield r.asDict()
        return

    # Fallback: SQL analytics endpoint of the lh_metadata Lakehouse
    import pyodbc
    conn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={os.environ['METADATA_SQL_ENDPOINT']};"
        f"Database={os.environ.get('METADATA_LAKEHOUSE_DB','lh_metadata')};"
        "Authentication=ActiveDirectoryServicePrincipal;Encrypt=yes;"
        f"UID={os.environ['AZURE_CLIENT_ID']};PWD={os.environ['AZURE_CLIENT_SECRET']};"
    )
    cur = conn.cursor()
    cur.execute(ROW_QUERY)
    cols = [c[0] for c in cur.description]
    for raw in cur.fetchall():
        yield dict(zip(cols, raw))

# ---- Helpers --------------------------------------------------------------
def fabric_lakehouse_qn(server, db, schema, table, column=None):
    """Compose the qualified name pattern Purview uses for Fabric Lakehouse
       tables that originated as mirrored copies of an Azure SQL DB."""
    base = (f"https://onelake.dfs.fabric.microsoft.com/"
            f"{os.environ['FABRIC_WORKSPACE_GUID']}/"
            f"{os.environ['FABRIC_LAKEHOUSE_GUID']}/Tables/{table}")
    return base + (f"#{column}" if column else "")

def powerbi_dataset_qn(workspace_id, dataset_id, table, column=None):
    base = f"https://app.powerbi.com/groups/{workspace_id}/datasets/{dataset_id}/tables/{table}"
    return base + (f"#columns/{column}" if column else "")

def update(qn, type_name, description, glossary_terms_csv=None):
    try:
        client.partial_update_entity(
            typeName       = type_name,
            qualifiedName  = qn,
            attributes     = {"description": description}
        )
        log.info("desc → %s", qn)
    except Exception as e:
        log.warning("skip %s: %s", qn, e)
        return

    if glossary_terms_csv:
        for term in [t.strip() for t in glossary_terms_csv.split(",") if t.strip()]:
            try:
                glossary.assignTerm(
                    entities=[{"typeName": type_name, "uniqueAttributes": {"qualifiedName": qn}}],
                    termName=term
                )
            except Exception as e:
                log.warning("term '%s' → %s skipped: %s", term, qn, e)

# ---- Main loop ------------------------------------------------------------
for r in read_rows():
    # 1. Source SQL asset (mssql_table / mssql_column) — ENRICHMENT ONLY,
    #    Purview holds the description; we never write back to MS_Description.
    if r["ColumnName"]:
        update(r["PurviewQualifiedName"], "mssql_column",
               r["ColumnDescription"], r["ColumnGlossaryTerms"])
    else:
        update(r["PurviewQualifiedName"],
               "mssql_table" if r["AssetType"] == "table" else "mssql_view",
               r["AssetDescription"], r["AssetGlossaryTerms"])

    # 2. Mirrored Fabric Lakehouse copy of the same table/column
    lh_qn = fabric_lakehouse_qn(
        r["ServerName"], r["DatabaseName"],
        r["SchemaName"], r["ObjectName"], r["ColumnName"]
    )
    update(
        lh_qn,
        "fabric_lakehouse_table_column" if r["ColumnName"] else "fabric_lakehouse_table",
        r["ColumnDescription"] if r["ColumnName"] else r["AssetDescription"],
        r["ColumnGlossaryTerms"] if r["ColumnName"] else r["AssetGlossaryTerms"],
    )

    # 3. Power BI / Direct Lake semantic model exposure (if mapped)
    ws  = os.environ.get("POWERBI_WORKSPACE_ID")
    ds  = os.environ.get("POWERBI_DATASET_ID")
    if ws and ds and r["ColumnName"]:
        update(
            powerbi_dataset_qn(ws, ds, r["ObjectName"], r["ColumnName"]),
            "powerbi_dataset_column",
            r["ColumnDescription"], r["ColumnGlossaryTerms"]
        )

log.info("Purview push complete.")
