"""
07_purview_register_lineage.py
Registers custom Atlas lineage edges that Fabric does not infer automatically:

  Azure SQL view / stored proc  →  mirrored Lakehouse Delta table  →  Direct Lake semantic model

Why this is needed:
  * Fabric Mirroring exposes table-to-table lineage but not the upstream view
    or stored-proc that feeds the table semantically.
  * Brookfield's business meaning lives in those views/procs, so they MUST
    appear as upstream nodes in lineage for governance.

Strategy:
  Use the Atlas 'Process' entity to model each view/proc as a transformation,
  with `inputs` = [source mssql_table entities] and
  `outputs` = [fabric_lakehouse_table entities] (and optionally the
  powerbi_dataset_table). Process entities are first-class lineage nodes
  in Purview.
"""
import os, pyodbc, json, logging
from pyapacheatlas.auth import ServicePrincipalAuthentication
from pyapacheatlas.core import PurviewClient, AtlasEntity, AtlasProcess

log = logging.getLogger("purview-lineage"); logging.basicConfig(level=logging.INFO)

auth   = ServicePrincipalAuthentication(
    tenant_id=os.environ["AZURE_TENANT_ID"],
    client_id=os.environ["AZURE_CLIENT_ID"],
    client_secret=os.environ["AZURE_CLIENT_SECRET"],
)
client = PurviewClient(account_name=os.environ["PURVIEW_NAME"], authentication=auth)

SQL_CONN = (
    "Driver={ODBC Driver 18 for SQL Server};"
    f"Server={os.environ['SQL_SERVER']};"
    f"Database={os.environ['SQL_DATABASE']};"
    "Authentication=ActiveDirectoryMsi;Encrypt=yes;"
)

# ---- Pull (object, upstream-objects) pairs from meta.* --------------------
QUERY = """
SELECT a.SchemaName, a.ObjectName, a.AssetType, a.UpstreamObjects,
       CONCAT('mssql://', @@SERVERNAME, '/', DB_NAME(), '/',
              a.SchemaName, '/', a.ObjectName) AS QName,
       CONCAT(@@SERVERNAME, '.', DB_NAME(), '.', a.SchemaName, '.', a.ObjectName) AS DisplayName
FROM   meta.AssetMetadata a
WHERE  a.AssetType IN ('view','proc')
  AND  a.UpstreamObjects IS NOT NULL
  AND  a.IsDraft = 0
"""

WORKSPACE_GUID = os.environ["FABRIC_WORKSPACE_GUID"]
LAKEHOUSE_GUID = os.environ["FABRIC_LAKEHOUSE_GUID"]
SERVER         = os.environ["SQL_SERVER_NAME"]      # short name as in @@SERVERNAME
DATABASE       = os.environ["SQL_DATABASE"]

def mssql_table_entity(schema, table):
    return AtlasEntity(
        name           = table,
        typeName       = "mssql_table",
        qualified_name = f"mssql://{SERVER}/{DATABASE}/{schema}/{table}",
        guid           = -hash((schema,table)) & 0xFFFFFFFF,   # local negative GUID
    )

def lakehouse_table_entity(table):
    qn = (f"https://onelake.dfs.fabric.microsoft.com/"
          f"{WORKSPACE_GUID}/{LAKEHOUSE_GUID}/Tables/{table}")
    return AtlasEntity(
        name=table, typeName="fabric_lakehouse_table",
        qualified_name=qn, guid=-(hash(qn) & 0xFFFFFFFF))

# ---- Build process entities -----------------------------------------------
processes = []
with pyodbc.connect(SQL_CONN) as cn:
    cur = cn.cursor()
    cur.execute(QUERY)
    cols = [c[0] for c in cur.description]
    for row in cur.fetchall():
        r = dict(zip(cols, row))
        upstream_qnames = [u.strip() for u in (r["UpstreamObjects"] or "").split(",") if u.strip()]
        inputs = []
        for uq in upstream_qnames:
            # accept "schema.table" or "[schema].[table]" forms
            parts = [p.strip("[] ") for p in uq.replace(".", " ").split() if p.strip("[] ")]
            if len(parts) >= 2:
                inputs.append(mssql_table_entity(parts[-2], parts[-1]))

        # outputs: assume same-named Lakehouse table (mirrored copy)
        outputs = [lakehouse_table_entity(r["ObjectName"])]

        proc = AtlasProcess(
            name           = f"{r['SchemaName']}.{r['ObjectName']}",
            typeName       = "Process",
            qualified_name = f"process://sql/{r['QName']}",
            inputs         = inputs,
            outputs        = outputs,
            guid           = -(hash(r["QName"]) & 0xFFFFFFFF),
            attributes     = {"description":
                f"{r['AssetType'].upper()} {r['SchemaName']}.{r['ObjectName']} – "
                "registered as transformation by metadata pipeline."},
        )
        processes.append(proc)

# ---- Upload ----------------------------------------------------------------
batch = []
for p in processes:
    batch.extend(p.inputs)
    batch.extend(p.outputs)
    batch.append(p)

if batch:
    res = client.upload_entities(batch=[e.to_json() for e in batch])
    log.info("Uploaded %d entities/processes (lineage edges).", len(batch))
else:
    log.info("No upstream-declared modules to register.")
