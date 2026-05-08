# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "d4ba455b-9b80-46dd-afe8-d0b877b3a5d2",
# META       "default_lakehouse_name": "lh_metadata",
# META       "default_lakehouse_workspace_id": "795ce5db-7ea0-4a7c-ba64-e27c9fb568f4",
# META       "known_lakehouses": [
# META         {
# META           "id": "d4ba455b-9b80-46dd-afe8-d0b877b3a5d2"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# Fabric Notebook: nb_04_generate_tmdl
# Gap: G3 — Metadata write-back to semantic model
# Purpose: Read descriptions / KPI defs / AI instructions from lh_metadata,
#          fetch the live BrookfieldEnercare TMDL via Fabric REST API,
#          inject descriptions, and push back to the semantic model.
#
# DEMO_MODE = True  → dry-run (prints what would be injected, no write)
# DEMO_MODE = False → live (fetches, injects, pushes — updates semantic model)
#
# Run order: after nb_04a (lh_metadata schema and seeds must exist)
# Default lakehouse: lh_metadata

DEMO_MODE    = True
WORKSPACE_ID = "795ce5db-7ea0-4a7c-ba64-e27c9fb568f4"
MODEL_NAME   = "BrookfieldEnercare"   # display name used to auto-discover MODEL_ID
METADATA_LH  = "lh_metadata"

print(f"nb_04_generate_tmdl  |  DEMO_MODE={DEMO_MODE}")
print(f"Workspace: {WORKSPACE_ID}  |  Target model: {MODEL_NAME}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ── Cell 2: Read metadata from lh_metadata ───────────────────────────────────
# vw_business_metadata_current columns (nb_04a schema):
#   RecordCategory='asset'  → ObjectKey=TableName, Description
#   RecordCategory='column' → ObjectKey='Table.Column', TriggerText=ColumnName, Description
# kpi_metadata and ai_metadata queried directly (falls back gracefully).

meta_df = spark.sql(f"SELECT * FROM {METADATA_LH}.vw_business_metadata_current")
rows    = meta_df.collect()

# Table descriptions — asset rows
table_descs = {
    r.ObjectKey: r.Description
    for r in rows
    if r.RecordCategory == "asset" and r.Description
}

# Column descriptions — column rows; ObjectKey = "TableName.ColumnName"
col_descs = {}
for r in rows:
    if r.RecordCategory == "column" and r.Description and r.TriggerText:
        tbl = r.ObjectKey.split(".")[0] if "." in r.ObjectKey else r.ObjectKey
        col_descs[(tbl, r.TriggerText)] = r.Description

# Certified KPI descriptions — IsCertified=1 gate (G2-4)
# Falls back to all KPIs if IsCertified column not yet added by nb_04a
try:
    kpi_df = spark.sql(
        f"SELECT KpiName, Description FROM {METADATA_LH}.kpi_metadata WHERE IsCertified = 1"
    )
    kpi_descs = {r.KpiName: r.Description for r in kpi_df.collect() if r.Description}
except Exception:
    kpi_descs = {}
    print("  [WARN] kpi_metadata missing IsCertified/Description — run nb_04a with DEMO_MODE=False first")

# AI instructions — falls back to [] if ai_metadata not yet created by nb_04a
try:
    ai_df = spark.sql(
        f"SELECT ResponseText FROM {METADATA_LH}.ai_metadata"
        f" WHERE IsDraft = 0 AND RecordType = 'ai_instruction'"
    )
    ai_instructions = [r.ResponseText for r in ai_df.collect() if r.ResponseText]
except Exception:
    ai_instructions = []
    print("  [WARN] ai_metadata not found — run nb_04a with DEMO_MODE=False to create it")

print(f"Loaded: {len(table_descs)} table descriptions, {len(col_descs)} column descriptions")
print(f"        {len(kpi_descs)} certified KPI descriptions, {len(ai_instructions)} AI instructions")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ── Cell 3: Fetch TMDL via Fabric REST API ────────────────────────────────────
# Uses mssparkutils managed identity token for the Power BI scope.
# GET definition returns a long-running op (202) — poll until 200.

import requests
import base64
import time

token   = mssparkutils.credentials.getToken("pbi")
headers = {
    "Authorization":  f"Bearer {token}",
    "Content-Type":   "application/json",
}

FABRIC_API = "https://api.fabric.microsoft.com/v1"

# Auto-discover MODEL_ID by display name
models_resp = requests.get(
    f"{FABRIC_API}/workspaces/{WORKSPACE_ID}/semanticModels",
    headers=headers,
)
models_resp.raise_for_status()
MODEL_ID = next(
    m["id"] for m in models_resp.json()["value"]
    if m["displayName"] == MODEL_NAME
)
print(f"Found model: {MODEL_NAME}  ({MODEL_ID})")


def _post_lro(url, hdrs, max_wait=120):
    """POST to a Fabric LRO endpoint; poll Location/result until Succeeded."""
    resp = requests.post(url, headers=hdrs)
    if resp.status_code == 200:
        return resp.json()
    if resp.status_code != 202:
        resp.raise_for_status()
    loc        = resp.headers["Location"]
    retry_secs = int(resp.headers.get("Retry-After", 20))
    waited     = 0
    while waited < max_wait:
        time.sleep(retry_secs)
        waited += retry_secs
        r = requests.get(loc, headers=hdrs)
        if r.status_code == 200 and r.json().get("status") == "Succeeded":
            result = requests.get(f"{loc}/result", headers=hdrs)
            result.raise_for_status()
            return result.json()
        if r.status_code not in (200, 202):
            r.raise_for_status()
    raise TimeoutError(f"LRO timed out after {max_wait}s: {url}")


defn_url = f"{FABRIC_API}/workspaces/{WORKSPACE_ID}/semanticModels/{MODEL_ID}/getDefinition"
defn     = _post_lro(defn_url, headers)

tmdl_files = {
    part["path"]: base64.b64decode(part["payload"]).decode("utf-8")
    for part in defn["definition"]["parts"]
}
print(f"Fetched {len(tmdl_files)} TMDL parts from {MODEL_NAME}")
for path in sorted(tmdl_files):
    print(f"  {path}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ── Cell 4: TMDL injection helpers ───────────────────────────────────────────
# Four pure functions that operate on TMDL string content.
# Each removes any existing description first, then re-inserts.
# Double-quotes in description text are replaced with single-quotes to avoid
# breaking TMDL string literals.

import re


def _safe(text: str) -> str:
    """Escape description text for TMDL string literal (double → single quote)."""
    return text.replace('"', "'").strip()


def inject_table_description(content: str, description: str) -> str:
    """Add/replace table-level description after the sourceLineageTag line."""
    desc_line = f'\tdescription: "{_safe(description)}"'
    # Remove any pre-existing table description
    content = re.sub(r'\n\tdescription: "[^"]*"', "", content, count=1)
    # Insert after the sourceLineageTag line
    return re.sub(
        r'(\tsourceLineageTag: \[dbo\]\.\[[\w_]+\])',
        f'\\1\n{desc_line}',
        content,
        count=1,
    )


def inject_column_description(content: str, source_column: str, description: str) -> str:
    """Add/replace column description after sourceColumn: {col} in its block."""
    desc_line = f'\t\tdescription: "{_safe(description)}"'
    sc_pattern = rf'(\t\tsourceColumn: {re.escape(source_column)})'
    # Remove pre-existing description immediately after this sourceColumn line
    content = re.sub(
        rf'(\t\tsourceColumn: {re.escape(source_column)})\n\t\tdescription: "[^"]*"',
        r'\1',
        content,
    )
    # Insert description after sourceColumn
    return re.sub(sc_pattern, f'\\1\n{desc_line}', content, count=1)


def inject_measure_description(content: str, measure_name: str, description: str) -> str:
    """Add/replace description line immediately after the measure formula line."""
    desc_line = f'\t\tdescription: "{_safe(description)}"'
    esc        = re.escape(measure_name)
    # Remove pre-existing description on the next line after the formula
    content = re.sub(
        rf"(measure '{esc}' = [^\n]+)\n\t\tdescription: \"[^\"]*\"",
        r'\1',
        content,
    )
    # Insert after formula line
    return re.sub(
        rf"(measure '{esc}' = [^\n]+)",
        f'\\1\n{desc_line}',
        content,
        count=1,
    )


def inject_ai_instructions(content: str, instructions_text: str) -> str:
    """Add/replace PBI_AI_Instructions annotation in model.tmdl."""
    new_ann = f'annotation PBI_AI_Instructions = "{_safe(instructions_text)}"'
    if "annotation PBI_AI_Instructions" in content:
        return re.sub(r'annotation PBI_AI_Instructions = "[^"]*"', new_ann, content)
    # Insert before the first 'ref table' line
    return re.sub(r'(ref table)', f'{new_ann}\n\n\\1', content, count=1)


print("Injection helpers loaded.")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ── Cell 5: Inject table and column descriptions ──────────────────────────────
# Loops all table TMDL files (excludes _Measures.tmdl).
# Injects table-level description if AssetName matches;
# injects column descriptions for matching (table, column) pairs.

TABLE_PARTS = [
    p for p in tmdl_files
    if p.startswith("definition/tables/") and not p.endswith("_Measures.tmdl")
]

injection_log = []

for path in TABLE_PARTS:
    table_name = path.split("/")[-1].replace(".tmdl", "")
    content    = tmdl_files[path]
    changes    = []

    # Table description
    if table_name in table_descs:
        content = inject_table_description(content, table_descs[table_name])
        changes.append("(table)")

    # Column descriptions
    for (tbl, col), desc in col_descs.items():
        if tbl == table_name:
            content = inject_column_description(content, col, desc)
            changes.append(col)

    if DEMO_MODE:
        tag = "[DRY RUN]"
    else:
        tmdl_files[path] = content
        tag = "[APPLIED]"

    label = f"{tag} {table_name}"
    if changes:
        print(f"  {label:<45} {len(changes)} injection(s): {changes}")
    else:
        print(f"  {label:<45} no metadata found — skipped")

    injection_log.append({"table": table_name, "changes": len(changes)})


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ── Cell 6: KPI descriptions — lh_metadata gate only ────────────────────────
# NOTE: TMDL does not support 'description' as a property on measure objects
# in the current Fabric API version. Measure descriptions are therefore stored
# exclusively in lh_metadata.kpi_metadata and surfaced via the Data Agent /
# vw_business_metadata_current. The IsCertified=1 gate still governs which
# KPIs propagate to Purview glossary (G6) and verified answers (G4).
#
# If a future Fabric release supports measure descriptions in TMDL, re-enable
# the inject_measure_description calls below.

kpi_changes = []
print(f"  [INFO] {len(kpi_descs)} certified KPI(s) in lh_metadata:")
for kpi_name, desc in kpi_descs.items():
    kpi_changes.append(kpi_name)
    print(f"    • {kpi_name}: {desc[:80]}{'...' if len(desc) > 80 else ''}")
print("  Measure descriptions are stored in lh_metadata only (TMDL measure "
      "description property not supported in current Fabric version).")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ── Cell 7: AI instructions + ref table sync in model.tmdl ───────────────────
# Combines all ai_instruction ResponseText values into one annotation.
# Also adds any missing 'ref table' entries for TMDL files present in the
# definition but not yet referenced in model.tmdl (handles CC tables).

model_path = "definition/model.tmdl"
content    = tmdl_files[model_path]
model_changes = []

# AI instructions
if ai_instructions:
    combined = " | ".join(ai_instructions)
    content  = inject_ai_instructions(content, combined)
    model_changes.append(f"PBI_AI_Instructions ({len(ai_instructions)} instructions)")
else:
    print("  No AI instructions in lh_metadata — skipping annotation")

# Sync ref table entries for any table TMDL files not yet referenced
referenced = set(re.findall(r'ref table (\S+)', content))
new_refs   = []
for path in tmdl_files:
    if path.startswith("definition/tables/") and not path.endswith("_Measures.tmdl"):
        tname = path.split("/")[-1].replace(".tmdl", "")
        if tname not in referenced:
            content  += f"\nref table {tname}"
            new_refs.append(tname)

if new_refs:
    model_changes.append(f"added ref table: {new_refs}")

if DEMO_MODE:
    tag = "[DRY RUN]"
else:
    tmdl_files[model_path] = content
    tag = "[APPLIED]"

print(f"  {tag} model.tmdl: {model_changes if model_changes else 'no changes'}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ── Cell 8: Push updated TMDL + summary ───────────────────────────────────────
# DEMO_MODE=False: re-encodes all TMDL parts and POSTs to updateDefinition.
# The endpoint is also a long-running op (202 → poll).
# Always prints an injection summary regardless of mode.

if not DEMO_MODE:
    parts = [
        {
            "path":        path,
            "payload":     base64.b64encode(c.encode("utf-8")).decode("utf-8"),
            "payloadType": "InlineBase64",
        }
        for path, c in tmdl_files.items()
    ]
    body     = {"definition": {"format": "TMDL", "parts": parts}}
    push_url = (
        f"{FABRIC_API}/workspaces/{WORKSPACE_ID}"
        f"/semanticModels/{MODEL_ID}/updateDefinition"
    )
    push_resp = requests.post(push_url, headers=headers, json=body)
    if push_resp.status_code in (200, 202):
        print(f"SUCCESS — {MODEL_NAME} semantic model updated via Fabric REST API.")
        if push_resp.status_code == 202:
            print("  (202 Accepted — changes applied asynchronously)")
    else:
        print(f"ERROR {push_resp.status_code}:\n{push_resp.text}")
else:
    print("DEMO_MODE=True — no changes written to the semantic model.")
    print("Set DEMO_MODE = False and re-run to apply descriptions live.\n")

# ── Injection summary ──
total_table_injections = sum(r["changes"] for r in injection_log)
print("\n=== Injection summary ===")
for r in injection_log:
    if r["changes"]:
        print(f"  {r['table']:<40} {r['changes']} injection(s)")
print(f"  {'_Measures.tmdl':<40} {len(kpi_changes)} KPI description(s) (IsCertified=1 only)")
print(f"  {'model.tmdl':<40} {len(model_changes)} change(s)")
print(f"\nTotal: {total_table_injections + len(kpi_changes)} description(s) processed")
print(f"Target model: {MODEL_NAME} ({MODEL_ID})")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
