---
mode: agent
description: "G6 + G7: nb_05_purview_push.py and nb_06_purview_lineage.py — adapt from archive scripts"
tools: ["filesystem"]
---

# G6 + G7 — Purview Integration: Descriptions, Glossary, and Lineage

## Archive scripts to adapt (do not start from scratch)
`archive/original/purview/06_purview_push_descriptions.py` → adapt for `nb_05_purview_push.py`
`archive/original/purview/07_purview_register_lineage.py`  → adapt for `nb_06_purview_lineage.py`

Read both archive files first, then produce the adapted versions.

## Auth pattern (use in both notebooks)
```python
import os, requests
from azure.identity import DefaultAzureCredential

PURVIEW_ACCOUNT = os.environ.get("PURVIEW_ACCOUNT_NAME", "# TODO: load from Key Vault")
BASE_URL = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"

credential = DefaultAzureCredential()
token = credential.get_token("https://purview.azure.net/.default").token
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
```

See `#file:context/api-endpoints.json` for all Purview Atlas endpoint patterns.
See `#file:context/purview-type-defs.json` for custom entity type definitions.

---

## Task 1 — nb_05_purview_push.py (G6)

Write `purview/nb_05_purview_push.py` as a Fabric notebook cell-by-cell source file.

### Cell 1 — Config
```python
DEMO_MODE = True
PURVIEW_ACCOUNT = os.environ.get("PURVIEW_ACCOUNT_NAME", "# TODO: load from Key Vault")
WORKSPACE_ID    = os.environ.get("FABRIC_WORKSPACE_ID", "# TODO: load from Key Vault")
LAKEHOUSE_ID    = os.environ.get("FABRIC_LAKEHOUSE_ID", "# TODO")

# Qualified name patterns (from context/api-endpoints.json)
def fabric_table_qname(schema, table):
    return f"fabric://{WORKSPACE_ID}/{LAKEHOUSE_ID}/tables/{schema}/{table}"

def fabric_model_qname(model_name="BrookfieldEnercare"):
    return f"powerbi://api.powerbi.com/v1.0/myorg/BrookfieldEnercare/{model_name}"
```

### Cell 2 — Register custom type defs (run once)
```python
# POST to /catalog/api/atlas/v2/types/typedefs
# Load type definitions from context/purview-type-defs.json
# Check if EnercareCallCenterTable already exists first — skip if present
# See context/purview-type-defs.json for full payload
```

### Cell 3 — Read metadata from lh_metadata
```python
# Pull only IsDraft=0 rows from vw_business_metadata_current
# Build entity payloads for:
#   1. Table-level assets (use EnercareCallCenterTable typeName)
#   2. Column-level assets (use azure_sql_column typeName)
# Apply EnercareOrphaned classification to ref_cc_billing_adj_category
# (demonstrates real governance gap from Enercare prod estate)
```

### Cell 4 — Push asset descriptions (batch, max 20 per call)
Using `pyapacheatlas` pattern from archive:
```python
from pyapacheatlas.core.client import PurviewClient
from pyapacheatlas.auth import ServicePrincipalAuthentication
# Adapt from archive/original/purview/06_purview_push_descriptions.py
# Push in batches of 20 via /catalog/api/atlas/v2/entity/bulk
```

In DEMO_MODE: print a sample of payloads (first 3 entities), don't POST.

### Cell 5 — Push certified KPI glossary terms (G6-6)
```python
# Read IsCertified=1 rows from lh_metadata.kpi_metadata
# POST each as a Purview glossary term:
# POST /catalog/api/atlas/v2/glossary/term
# {
#   "name": KPIName,
#   "longDescription": Description,
#   "abbreviation": KPICode,
#   "usage": Formula,
#   "status": "Approved"
# }
# Save returned term GUIDs to context/glossary_term_guids.json
```

### Cell 6 — Apply EnercareBusinessSemantics business metadata
For each registered column asset, apply the custom business metadata attributes
from `EnercareBusinessSemantics` (defined in `context/purview-type-defs.json`):
- `BusinessDefinition`, `LinkedKPICode`, `DataSteward`, `SourceSystem`, `CertifiedFlg`

Use `PUT /catalog/api/atlas/v2/entity/guid/{guid}/businessmetadata/EnercareBusinessSemantics`

### Cell 7 — Loop-close: write AI insight annotation
```python
def write_insight_to_purview(asset_qualified_name, insight_text, linked_kpi_codes, generated_by="standalone_copilot"):
    """
    Writes an AI-generated insight back to a Purview asset as business metadata.
    This is the loop-close step — called after Copilot generates an insight.

    Demo call (the closing moment):
    write_insight_to_purview(
        asset_qualified_name=fabric_table_qname("dbo", "ref_cc_billing_adj_category"),
        insight_text="41% of PP non-renewals in Q1 followed billing queue calls where customers mentioned invoice confusion. Billing adjustment categories correlate with PP_RNW_RATE decline. Recommend adding descriptions to invoice_date fields across ZUORA/NS/CLARIFY.",
        linked_kpi_codes=["PP_RNW_RATE", "CSAT"],
        generated_by="standalone_copilot"
    )
    """
    # 1. GET entity GUID by qualifiedName
    # 2. PUT business metadata to /entity/guid/{guid}/businessmetadata/EnercareBusinessSemantics
    # 3. Set AIInstruction attribute to insight_text
    # 4. Print: "Loop closed — insight written to {asset_qualified_name}"
```

### Cell 8 — Summary
```python
print("=== nb_05_purview_push complete ===")
print(f"Assets registered:    {n_assets}")
print(f"Columns registered:   {n_columns}")
print(f"Glossary terms:       {n_terms} certified KPIs")
print(f"Business metadata:    {n_bm} columns attributed")
print(f"Orphaned assets flagged: ref_cc_billing_adj_category")
```

---

## Task 2 — nb_06_purview_lineage.py (G7)

Write `purview/nb_06_purview_lineage.py`. Adapt from `archive/original/purview/07_purview_register_lineage.py`.

### Read lineage_edges from lh_metadata
```python
df_edges = spark.sql("SELECT * FROM lh_metadata.lineage_edges ORDER BY EdgeID")
```

### For each edge, register an Atlas Process entity
```python
# Pattern from api-endpoints.json create_relationship
# POST /catalog/api/atlas/v2/entity/bulk
# Entity type: Process
# inputs: [{"guid": source_guid, "typeName": source_type}]
# outputs: [{"guid": target_guid, "typeName": target_type}]
# name: edge.ProcessName
# qualifiedName: f"process://{edge.ProcessName}/{edge.SourceQName}/{edge.TargetQName}"
```

Seed `lh_metadata.lineage_edges` with these rows before running (add as Cell 1):

| SourceQName | TargetQName | ProcessName | TransformType |
|---|---|---|---|
| `clarify://enercare.prod/crm` | `fabric://{ws}/{lh}/tables/fct_cc_interactions` | nb_01_setup_demo_environment | notebook |
| `zuora://enercare.prod/billing` | `fabric://{ws}/{lh}/tables/billing_transactions` | nb_01_setup_demo_environment | notebook |
| `fabric://{ws}/{lh}/tables/fct_cc_interactions` | `powerbi://api.../BrookfieldEnercare/fct_cc_interactions` | BrookfieldEnercare.SemanticModel | direct_lake |
| `fabric://{ws}/{lh}/tables/fct_billing` | `powerbi://api.../BrookfieldEnercare/fct_billing` | BrookfieldEnercare.SemanticModel | direct_lake |
| `fabric://{ws}/{lh}/tables/fct_service_request` | `powerbi://api.../BrookfieldEnercare/fct_service_request` | BrookfieldEnercare.SemanticModel | direct_lake |

Use `{WORKSPACE_ID}` and `{LAKEHOUSE_ID}` from Cell 1 config. Replace `{ws}` and `{lh}` at runtime.

Print a lineage summary on completion:
```
Lineage edges registered: N
Graph depth: source system → OneLake → semantic model (2 hops)
View in Purview: https://{PURVIEW_ACCOUNT}.purview.azure.com/catalog/lineage
```

---

After creating both files, update `docs/design-gap-analysis.md`:
- G6-3, G6-4, G6-5, G6-6: `🟢 Done`
- G6-1, G6-2 (auth setup): `🟡 In Progress` (credentials still needed — TODOs in code)
- G7-1, G7-2, G7-3, G7-4, G7-5: `🟢 Done`
