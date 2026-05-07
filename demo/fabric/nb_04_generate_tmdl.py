# ---------------------------------------------------------------------------
# demo/fabric/nb_04_generate_tmdl.py
# Python source mirror of pbi/nb_04_generate_tmdl.Notebook/notebook-content.py
# Gap: G3 — Metadata write-back to BrookfieldEnercare semantic model
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# CELL 1 — Config
# ---------------------------------------------------------------------------

# DEMO_MODE = True  → dry-run (prints what would be injected, no write)
# DEMO_MODE = False → live (fetches, injects, pushes — updates semantic model)

DEMO_MODE    = True
WORKSPACE_ID = "795ce5db-7ea0-4a7c-ba64-e27c9fb568f4"
MODEL_NAME   = "BrookfieldEnercare"
METADATA_LH  = "lh_metadata"

print(f"nb_04_generate_tmdl  |  DEMO_MODE={DEMO_MODE}")
print(f"Workspace: {WORKSPACE_ID}  |  Target model: {MODEL_NAME}")


# ---------------------------------------------------------------------------
# CELL 2 — Read metadata from lh_metadata
# ---------------------------------------------------------------------------

meta_df = spark.sql(f"SELECT * FROM {METADATA_LH}.vw_business_metadata_current")

table_descs = {
    r.ObjectKey: r.Description
    for r in meta_df.filter("RecordCategory = 'asset'").collect()
    if r.Description
}

col_descs = {}
for r in meta_df.filter("RecordCategory = 'column'").collect():
    if r.Description and r.TriggerText and r.ObjectKey and "." in r.ObjectKey:
        asset = r.ObjectKey.split(".")[0]
        col_descs[(asset, r.TriggerText)] = r.Description

kpi_df = spark.sql(
    f"SELECT KPIName, Description FROM {METADATA_LH}.kpi_metadata WHERE IsCertified = 1"
)
kpi_descs = {r.KPIName: r.Description for r in kpi_df.collect() if r.Description}

ai_instructions = [
    r.ResponseText
    for r in meta_df.filter("RecordCategory = 'ai_instruction'").collect()
    if r.ResponseText
]

print(f"Loaded: {len(table_descs)} table descriptions, {len(col_descs)} column descriptions")
print(f"        {len(kpi_descs)} certified KPI descriptions, {len(ai_instructions)} AI instructions")


# ---------------------------------------------------------------------------
# CELL 3 — Fetch TMDL via Fabric REST API
# ---------------------------------------------------------------------------

import requests
import base64
import time

token   = mssparkutils.credentials.getToken("pbi")
headers = {
    "Authorization":  f"Bearer {token}",
    "Content-Type":   "application/json",
}

FABRIC_API = "https://api.fabric.microsoft.com/v1"

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


def _poll_lro(url, hdrs, max_wait=90):
    resp = requests.get(url, headers=hdrs)
    if resp.status_code == 200:
        return resp.json()
    if resp.status_code != 202:
        resp.raise_for_status()
    loc = resp.headers.get("Location", url)
    for _ in range(max_wait):
        time.sleep(1)
        r = requests.get(loc, headers=hdrs)
        if r.status_code == 200:
            return r.json()
        if r.status_code not in (202, 200):
            r.raise_for_status()
    raise TimeoutError(f"LRO timed out after {max_wait}s: {url}")


defn_url = f"{FABRIC_API}/workspaces/{WORKSPACE_ID}/semanticModels/{MODEL_ID}/definition"
defn     = _poll_lro(defn_url, headers)

tmdl_files = {
    part["path"]: base64.b64decode(part["payload"]).decode("utf-8")
    for part in defn["definition"]["parts"]
}
print(f"Fetched {len(tmdl_files)} TMDL parts from {MODEL_NAME}")
for path in sorted(tmdl_files):
    print(f"  {path}")


# ---------------------------------------------------------------------------
# CELL 4 — TMDL injection helpers
# ---------------------------------------------------------------------------

import re


def _safe(text: str) -> str:
    return text.replace('"', "'").strip()


def inject_table_description(content: str, description: str) -> str:
    desc_line = f'\tdescription: "{_safe(description)}"'
    content   = re.sub(r'\n\tdescription: "[^"]*"', "", content, count=1)
    return re.sub(
        r'(\tsourceLineageTag: \[dbo\]\.\[[\w_]+\])',
        f'\\1\n{desc_line}',
        content, count=1,
    )


def inject_column_description(content: str, source_column: str, description: str) -> str:
    desc_line  = f'\t\tdescription: "{_safe(description)}"'
    sc_pattern = rf'(\t\tsourceColumn: {re.escape(source_column)})'
    content    = re.sub(
        rf'(\t\tsourceColumn: {re.escape(source_column)})\n\t\tdescription: "[^"]*"',
        r'\1', content,
    )
    return re.sub(sc_pattern, f'\\1\n{desc_line}', content, count=1)


def inject_measure_description(content: str, measure_name: str, description: str) -> str:
    desc_line = f'\t\tdescription: "{_safe(description)}"'
    esc       = re.escape(measure_name)
    content   = re.sub(
        rf"(measure '{esc}' = [^\n]+)\n\t\tdescription: \"[^\"]*\"",
        r'\1', content,
    )
    return re.sub(
        rf"(measure '{esc}' = [^\n]+)",
        f'\\1\n{desc_line}',
        content, count=1,
    )


def inject_ai_instructions(content: str, instructions_text: str) -> str:
    new_ann = f'annotation PBI_AI_Instructions = "{_safe(instructions_text)}"'
    if "annotation PBI_AI_Instructions" in content:
        return re.sub(r'annotation PBI_AI_Instructions = "[^"]*"', new_ann, content)
    return re.sub(r'(ref table)', f'{new_ann}\n\n\\1', content, count=1)


print("Injection helpers loaded.")


# ---------------------------------------------------------------------------
# CELL 5 — Inject table and column descriptions
# ---------------------------------------------------------------------------

TABLE_PARTS = [
    p for p in tmdl_files
    if p.startswith("definition/tables/") and not p.endswith("_Measures.tmdl")
]

injection_log = []

for path in TABLE_PARTS:
    table_name = path.split("/")[-1].replace(".tmdl", "")
    content    = tmdl_files[path]
    changes    = []

    if table_name in table_descs:
        content = inject_table_description(content, table_descs[table_name])
        changes.append("(table)")

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


# ---------------------------------------------------------------------------
# CELL 6 — Inject KPI descriptions into _Measures.tmdl (IsCertified=1 gate)
# ---------------------------------------------------------------------------

measures_path = "definition/tables/_Measures.tmdl"
content       = tmdl_files[measures_path]
kpi_changes   = []

for kpi_name, desc in kpi_descs.items():
    if f"measure '{kpi_name}'" in content:
        content = inject_measure_description(content, kpi_name, desc)
        kpi_changes.append(kpi_name)
    else:
        print(f"  WARNING: KPI '{kpi_name}' not found in _Measures.tmdl — skipped")

if DEMO_MODE:
    tag = "[DRY RUN]"
else:
    tmdl_files[measures_path] = content
    tag = "[APPLIED]"

print(f"  {tag} _Measures.tmdl: {len(kpi_changes)} certified KPI description(s)")
if kpi_changes:
    for k in kpi_changes:
        print(f"    • {k}")


# ---------------------------------------------------------------------------
# CELL 7 — AI instructions + ref table sync in model.tmdl
# ---------------------------------------------------------------------------

model_path    = "definition/model.tmdl"
content       = tmdl_files[model_path]
model_changes = []

if ai_instructions:
    combined = " | ".join(ai_instructions)
    content  = inject_ai_instructions(content, combined)
    model_changes.append(f"PBI_AI_Instructions ({len(ai_instructions)} instructions)")
else:
    print("  No AI instructions in lh_metadata — skipping annotation")

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


# ---------------------------------------------------------------------------
# CELL 8 — Push updated TMDL + summary
# ---------------------------------------------------------------------------

if not DEMO_MODE:
    parts = [
        {
            "path":        path,
            "payload":     base64.b64encode(c.encode("utf-8")).decode("utf-8"),
            "payloadType": "InlineBase64",
        }
        for path, c in tmdl_files.items()
    ]
    body      = {"definition": {"format": "TMDL", "parts": parts}}
    push_url  = (
        f"{FABRIC_API}/workspaces/{WORKSPACE_ID}"
        f"/semanticModels/{MODEL_ID}/definition?updateMode=UpdateDefinition"
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

total_table_injections = sum(r["changes"] for r in injection_log)
print("\n=== Injection summary ===")
for r in injection_log:
    if r["changes"]:
        print(f"  {r['table']:<40} {r['changes']} injection(s)")
print(f"  {'_Measures.tmdl':<40} {len(kpi_changes)} KPI description(s) (IsCertified=1 only)")
print(f"  {'model.tmdl':<40} {len(model_changes)} change(s)")
print(f"\nTotal: {total_table_injections + len(kpi_changes)} description(s) processed")
print(f"Target model: {MODEL_NAME} ({MODEL_ID})")
