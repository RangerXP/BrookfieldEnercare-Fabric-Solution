"""
ai_gap_fill.py
Optional AI assist: where a view/proc/column has no @description tag, ask
Azure OpenAI to draft one from the SQL source. Drafts are persisted with
IsDraft = 1 so a steward must approve before they propagate to extended
properties / Fabric / Purview.

Usage (from CI or a scheduled Fabric notebook):
    python ai_gap_fill.py --since-hours 24

Environment:
    AZURE_OPENAI_ENDPOINT  = https://<aoai>.openai.azure.com/
    AZURE_OPENAI_API_KEY   = ...
    AZURE_OPENAI_DEPLOYMENT= gpt-4o-mini    (or any chat-completion model)
    SQL_SERVER, SQL_DATABASE  (Active Directory MSI auth)
"""
import os, json, argparse, pyodbc, logging
from openai import AzureOpenAI

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
log = logging.getLogger("ai-gap-fill")

aoai = AzureOpenAI(
    azure_endpoint = os.environ["AZURE_OPENAI_ENDPOINT"],
    api_key        = os.environ["AZURE_OPENAI_API_KEY"],
    api_version    = "2024-10-21",
)
DEPLOYMENT = os.environ["AZURE_OPENAI_DEPLOYMENT"]

SYSTEM_PROMPT = (
    "You are a data steward at Brookfield Enercare. Given the SQL definition "
    "of a view or stored procedure, write a concise, accurate description "
    "(2-3 sentences) of what business question or process it serves. "
    "Then list each output column with a one-sentence business meaning. "
    "Use plain language a non-engineer can understand. Output strict JSON: "
    '{"asset_description": "...", "columns": [{"name":"...","description":"..."}]}'
)

CONN_STR = (
    "Driver={ODBC Driver 18 for SQL Server};"
    f"Server={os.environ['SQL_SERVER']};"
    f"Database={os.environ['SQL_DATABASE']};"
    "Authentication=ActiveDirectoryMsi;Encrypt=yes;"
)

def fetch_targets(cur, since_hours):
    cur.execute(f"""
        SELECT a.SchemaName, a.ObjectName, a.AssetType, m.[definition]
        FROM   meta.AssetMetadata a
        LEFT JOIN sys.objects o ON o.name = a.ObjectName
        LEFT JOIN sys.schemas s ON s.schema_id = o.schema_id AND s.name = a.SchemaName
        LEFT JOIN sys.sql_modules m ON m.[object_id] = o.[object_id]
        WHERE  (a.[Description] IS NULL OR a.IsDraft = 1)
          AND  m.[definition] IS NOT NULL
          AND  a.LastExtractedUtc >= DATEADD(hour, -?, SYSUTCDATETIME())
    """, since_hours)
    return cur.fetchall()

def upsert_drafts(cur, schema, obj, asset_desc, columns):
    cur.execute("""
        UPDATE meta.AssetMetadata
        SET [Description] = COALESCE([Description], ?), IsDraft = 1,
            LastExtractedUtc = SYSUTCDATETIME()
        WHERE SchemaName = ? AND ObjectName = ?;
    """, asset_desc, schema, obj)
    for c in columns:
        cur.execute("""
            MERGE meta.ColumnMetadata AS tgt
            USING (SELECT ? AS SchemaName, ? AS ObjectName, ? AS ColumnName, ? AS Descr) AS src
               ON tgt.SchemaName = src.SchemaName
              AND tgt.ObjectName = src.ObjectName
              AND tgt.ColumnName = src.ColumnName
            WHEN MATCHED AND tgt.[Description] IS NULL THEN
                UPDATE SET [Description] = src.Descr, IsDraft = 1,
                           LastExtractedUtc = SYSUTCDATETIME()
            WHEN NOT MATCHED THEN
                INSERT (SchemaName, ObjectName, ColumnName, [Description], IsDraft)
                VALUES (src.SchemaName, src.ObjectName, src.ColumnName, src.Descr, 1);
        """, schema, obj, c["name"], c["description"])

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--since-hours", type=int, default=24)
    args = ap.parse_args()

    with pyodbc.connect(CONN_STR, autocommit=False) as cn:
        cur = cn.cursor()
        targets = fetch_targets(cur, args.since_hours)
        log.info("Drafting descriptions for %d objects", len(targets))

        for schema, obj, atype, body in targets:
            user_msg = f"-- {atype.upper()} {schema}.{obj}\n{body}"
            try:
                resp = aoai.chat.completions.create(
                    model=DEPLOYMENT,
                    messages=[
                        {"role":"system","content":SYSTEM_PROMPT},
                        {"role":"user",  "content":user_msg[:18000]},
                    ],
                    temperature=0.2,
                    response_format={"type":"json_object"},
                )
                draft = json.loads(resp.choices[0].message.content)
                upsert_drafts(cur, schema, obj,
                              draft.get("asset_description"),
                              draft.get("columns", []))
                cn.commit()
                log.info("draft saved: %s.%s", schema, obj)
            except Exception as e:
                cn.rollback()
                log.warning("AI draft failed for %s.%s: %s", schema, obj, e)

if __name__ == "__main__":
    main()
