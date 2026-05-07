---
mode: agent
description: "G3: Build nb_04_generate_tmdl.py — reads lh_metadata, renders TMDL, commits to repo"
tools: ["filesystem"]
---

# G3 — nb_04_generate_tmdl.py: TMDL Write-Back Pipeline

## What this notebook does
This is the **core missing piece** of the pipeline. It reads enriched metadata from
`lh_metadata.vw_business_metadata_current`, renders updated TMDL for each semantic model
table file, and writes the changes back to the git repo so Fabric Source Control sync
can apply them to the live semantic model.

This is the answer to Christopher Dingle's question from 2026-05-05:
"Any friendly Fabric Python alternatives to TOM? Or do we need a Windows VM?"
Answer: git-based TMDL pipeline — no TOM, no XMLA endpoint, no Windows VM.

## Target files
TMDL output directory: `pbi/BrookfieldEnercare.SemanticModel/definition/tables/`
Existing table files:
`_Measures.tmdl`, `dim_customer.tmdl`, `dim_date.tmdl`, `dim_equipment.tmdl`,
`dim_product.tmdl`, `dim_service_account.tmdl`, `fct_billing.tmdl`,
`fct_contract_month.tmdl`, `fct_service_request.tmdl`
New files (from prompt 02): `fct_cc_interactions.tmdl`, `dim_cc_agent.tmdl`, `dim_cc_billing_adj.tmdl`

## Output file
`demo/fabric/nb_04_generate_tmdl.py` — Fabric notebook source, cell-by-cell with `# CELL **` separators.

---

## Cell Structure

### Cell 1 — Config
```python
DEMO_MODE = True   # True = dry-run (print diffs only); False = write files + commit
SEMANTIC_MODEL_PATH = "pbi/BrookfieldEnercare.SemanticModel/definition/tables"
METADATA_LAKEHOUSE = "lh_metadata"
MODEL_NAME = "BrookfieldEnercare"
BRANCH = "enercare"

# TODO: set git identity for commit (load from Key Vault in production)
GIT_USER_NAME  = "Enercare Metadata Pipeline"
GIT_USER_EMAIL = "metadata-pipeline@enercare.ca"
```

### Cell 2 — Read enriched metadata
```python
# Read descriptions from lh_metadata view
df_assets   = spark.sql("SELECT AssetName, Description, Owner, Steward, Domain FROM lh_metadata.vw_business_metadata_current WHERE SourceTable = 'asset_metadata'")
df_columns  = spark.sql("SELECT AssetName, ColumnName, Description FROM lh_metadata.vw_business_metadata_current WHERE SourceTable = 'column_metadata' AND IsDraft = 0")
df_kpis     = spark.sql("SELECT KPICode, KPIName, Formula, Description, TargetValue, UnitType FROM lh_metadata.kpi_metadata WHERE IsCertified = 1")
df_ai       = spark.sql("SELECT RecordType, TriggerText, ResponseText, LinkedKPICode FROM lh_metadata.ai_metadata WHERE IsDraft = 0")

# Build lookup dict: {table_name: {col_name: description}}
col_desc = {}
for row in df_columns.collect():
    col_desc.setdefault(row.AssetName, {})[row.ColumnName] = row.Description

# Build asset desc dict: {table_name: description}
asset_desc = {row.AssetName: row.Description for row in df_assets.collect()}
```

### Cell 3 — TMDL patch function
```python
import re

def patch_tmdl_descriptions(tmdl_text: str, table_name: str) -> tuple[str, int]:
    """
    Injects description fields into an existing TMDL file.
    Rules:
    - Preserves ALL existing lineageTag, sourceLineageTag, annotation, partition blocks
    - Only adds/updates 'description' property on table and column definitions
    - Does NOT add descriptions where column_metadata has no entry (leave undescribed)
    - Returns (patched_text, change_count)
    """
    changes = 0

    # 1. Inject table-level description after the table header line
    if table_name in asset_desc and asset_desc[table_name]:
        desc = asset_desc[table_name].replace('"', '\\"')
        table_pattern = rf'(^table {re.escape(table_name)}\s*\n)'
        if not re.search(r'^\s+description\s*=', tmdl_text, re.MULTILINE):
            tmdl_text = re.sub(table_pattern,
                               rf'\1\tdescription = "{desc}"\n',
                               tmdl_text, count=1, flags=re.MULTILINE)
            changes += 1

    # 2. Inject column descriptions
    if table_name in col_desc:
        for col_name, col_desc_text in col_desc[table_name].items():
            if not col_desc_text:
                continue
            desc = col_desc_text.replace('"', '\\"')
            # Find the column block and inject description after 'column {col_name}'
            col_pattern = rf'(\bcolumn {re.escape(col_name)}\s*\n(?!\s+description))'
            replacement = rf'\1\t\tdescription = "{desc}"\n'
            new_text, n = re.subn(col_pattern, replacement, tmdl_text, count=1)
            if n:
                tmdl_text = new_text
                changes += 1

    return tmdl_text, changes
```

### Cell 4 — Read, patch, write or diff each TMDL file
```python
import os

tmdl_dir = SEMANTIC_MODEL_PATH
total_changes = 0
changed_files = []

for fname in os.listdir(tmdl_dir):
    if not fname.endswith(".tmdl") or fname in ("model.tmdl", "database.tmdl",
                                                  "expressions.tmdl", "relationships.tmdl"):
        continue

    table_name = fname.replace(".tmdl", "")
    fpath = os.path.join(tmdl_dir, fname)

    with open(fpath, "r", encoding="utf-8") as f:
        original = f.read()

    patched, n_changes = patch_tmdl_descriptions(original, table_name)
    total_changes += n_changes

    if n_changes > 0:
        changed_files.append(fname)
        if DEMO_MODE:
            # Print unified diff
            import difflib
            diff = list(difflib.unified_diff(
                original.splitlines(keepends=True),
                patched.splitlines(keepends=True),
                fromfile=f"a/{fname}", tofile=f"b/{fname}", n=2
            ))
            print(f"\n--- {fname} ({n_changes} changes) ---")
            print("".join(diff[:40]))  # cap diff output for readability
        else:
            with open(fpath, "w", encoding="utf-8") as f:
                f.write(patched)
            print(f"  {fname}: {n_changes} descriptions injected")

print(f"\nTotal: {total_changes} descriptions across {len(changed_files)} files")
if DEMO_MODE:
    print("DEMO_MODE=True — no files written. Set DEMO_MODE=False to apply.")
```

### Cell 5 — Inject _Measures descriptions from kpi_metadata
```python
# Patch _Measures.tmdl with descriptions from kpi_metadata
measures_path = os.path.join(tmdl_dir, "_Measures.tmdl")
with open(measures_path, "r", encoding="utf-8") as f:
    measures_text = f.read()

kpi_rows = df_kpis.collect()
m_changes = 0
for kpi in kpi_rows:
    measure_name = kpi.KPIName
    desc = f"{kpi.Description} Target: {kpi.TargetValue} {kpi.UnitType}.".replace('"', '\\"')
    pattern = rf"(measure '{re.escape(measure_name)}'\s*=.*?\n)(?!\s+description)"
    replacement = rf'\1\t\tdescription = "{desc}"\n'
    new_text, n = re.subn(pattern, replacement, measures_text, count=1)
    if n:
        measures_text = new_text
        m_changes += 1

print(f"_Measures.tmdl: {m_changes} measure descriptions injected")
if not DEMO_MODE:
    with open(measures_path, "w", encoding="utf-8") as f:
        f.write(measures_text)
```

### Cell 6 — Git commit (DEMO_MODE=False only)
```python
if not DEMO_MODE:
    import subprocess

    def run(cmd):
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd="/lakehouse/default/")
        if result.returncode != 0:
            print(f"ERROR: {result.stderr}")
        return result.stdout.strip()

    run(f'git config user.name "{GIT_USER_NAME}"')
    run(f'git config user.email "{GIT_USER_EMAIL}"')
    run(f"git checkout {BRANCH}")
    run(f"git add {tmdl_dir}/")
    commit_msg = f"chore: inject metadata descriptions from lh_metadata ({total_changes} changes)\n\nGenerated by nb_04_generate_tmdl. Source: lh_metadata.vw_business_metadata_current"
    run(f'git commit -m "{commit_msg}"')
    # NOTE: git push requires PAT or SSH key — load from Key Vault
    # TODO: run(f"git push origin {BRANCH}")
    print(f"Committed {total_changes} TMDL changes to branch '{BRANCH}'")
    print("Next step: trigger Fabric Source Control sync in the workspace to apply changes to the live semantic model")
else:
    print("DEMO_MODE=True — git commit skipped.")
```

### Cell 7 — Summary
```python
print("\n=== nb_04_generate_tmdl complete ===")
print(f"Mode:           {'DRY RUN' if DEMO_MODE else 'LIVE'}")
print(f"TMDL files:     {len(changed_files)} modified")
print(f"Descriptions:   {total_changes} injected")
print(f"KPI measures:   {m_changes} described")
if not DEMO_MODE:
    print(f"Committed to:   branch '{BRANCH}'")
    print("Action needed:  Sync via Fabric Source Control to apply to live model")
```

---

After writing the file, update `docs/design-gap-analysis.md`:
- G3-1: `🟢 Done`
- G3-2: `🟢 Done`
- G3-7 is already `🟢 Done`
- G3-3, G3-4 (AI instructions + verified answers injection): `🟡 In Progress` — Cell 5 covers measure descriptions; full AI instruction block requires Cell 5 extension once `ai_metadata` is populated (G4)
