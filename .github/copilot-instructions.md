# GitHub Copilot Instructions — Brookfield Enercare Fabric Solution

## What This Repo Is
End-to-end Microsoft Fabric + Purview + Copilot governance demo for Brookfield Enercare,
a Canadian home services company (HVAC, water heaters, Protection Plans, Ecobee smart thermostats).
Primary stakeholder: Christopher Dingle, VP Data Analytics & Governance.
Microsoft SE: Sean Kelley. Repo owner: RangerXP/BrookfieldEnercare-Fabric-Solution.

---

## Actual Repo Structure (do not invent new top-level folders)

```
/
├── demo/                          ← run guide, SQL seed scripts, nb Python source files
│   ├── README.md                  ← demo run order and prerequisites
│   ├── sql/
│   │   ├── 00_demo_schema_and_headers.sql   ← T-SQL schema + 4 views with @tag headers
│   │   └── 01_demo_seed_data.sql
│   └── fabric/
│       ├── nb_01_setup_demo_environment.py  ← Cell-by-cell Python for Fabric notebook
│       └── nb_02_metadata_pipeline_demo.py  ← 5-phase pipeline source
│
├── docs/
│   └── design-gap-analysis.md    ← AUTHORITATIVE build backlog (11 gaps, owners, statuses)
│
├── metadata/                      ← Fabric item definitions synced from workspace
│   ├── lh_enercare_demo.Lakehouse/
│   ├── lh_metadata.Lakehouse/
│   ├── Enercare Governance Agent.DataAgent/
│   ├── nb_01_setup_demo_environment.Notebook/
│   ├── nb_02_metadata_pipeline_demo.Notebook/
│   └── nb_03_pbi_star_schema.Notebook/
│
├── pbi/                           ← Fabric Source Control export (Power BI items)
│   ├── BrookfieldEnercare.pbip
│   ├── BrookfieldEnercare.Report/
│   ├── BrookfieldEnercare.SemanticModel/
│   │   ├── definition.pbism
│   │   └── definition/
│   │       ├── model.tmdl
│   │       ├── database.tmdl
│   │       ├── expressions.tmdl  ← DirectLake connection to lh_enercare_demo
│   │       ├── relationships.tmdl
│   │       └── tables/           ← ONE .tmdl FILE PER TABLE — write-back target
│   │           ├── _Measures.tmdl
│   │           ├── dim_customer.tmdl
│   │           ├── dim_date.tmdl
│   │           ├── dim_equipment.tmdl
│   │           ├── dim_product.tmdl
│   │           ├── dim_service_account.tmdl
│   │           ├── fct_billing.tmdl
│   │           ├── fct_contract_month.tmdl
│   │           └── fct_service_request.tmdl
│   ├── Enercare Governance Agent.DataAgent/
│   ├── lh_enercare_demo.Lakehouse/
│   ├── lh_metadata.Lakehouse/
│   ├── nb_01_setup_demo_environment.Notebook/
│   ├── nb_02_metadata_pipeline_demo.Notebook/
│   └── nb_03_pbi_star_schema.Notebook/
│
├── purview/                       ← Purview scripts (currently empty — build here)
├── sql/                           ← SQL scripts (currently empty — build here)
├── diagrams/                      ← empty
├── .gitignore
└── README.md
```

**New notebooks go in `demo/fabric/` as `nb_0N_name.py` (cell-by-cell Python source).**
**New Purview scripts go in `purview/` as `nb_0N_name.py`.**
**New SQL scripts go in `sql/`.**

---

## What Is Already Built — Do Not Regenerate

### Notebooks (complete, do not replace)
| Notebook | File | What it does |
|---|---|---|
| nb_01 | `demo/fabric/nb_01_setup_demo_environment.py` | Creates all Delta tables in `lh_enercare_demo` inline (no SQL Server needed). 50 customers, 10 products, 56 service accounts, 38 equipment, 31 service requests, ~300 billing rows |
| nb_02 | `demo/fabric/nb_02_metadata_pipeline_demo.py` | 5-phase metadata pipeline. `DEMO_MODE=True` = dry-run. `DEMO_MODE=False` = live Purview push. Already parses @tag headers from SQL views |
| nb_03 | `pbi/nb_03_pbi_star_schema.Notebook/` | Builds star schema in lh_enercare_demo |

### Semantic Model (complete TMDL — do not regenerate from scratch)
9 tables in `pbi/BrookfieldEnercare.SemanticModel/definition/tables/`:
- `dim_customer`, `dim_date`, `dim_equipment`, `dim_product`, `dim_service_account`
- `fct_billing`, `fct_contract_month`, `fct_service_request`
- `_Measures` (hidden measures table)

12 existing DAX measures in `_Measures.tmdl`:
`Total MRR`, `New MRR`, `Churned MRR`, `Net MRR Change`, `Active Customer Count`,
`Active Contract Count`, `Avg Lifetime Value`, `Avg Tenure Months`,
`SLA Breach Count`, `SLA Compliance Rate`, `Warranty Coverage Rate`, `Avg Equipment Age Years`

All tables use `mode: directLake` pointing to `lh_enercare_demo`.

### lh_metadata — Existing Tables (extend, do not drop/recreate)
- `asset_metadata` — asset-level metadata (owner, steward, domain, sensitivity, IsDraft, DefinitionHash)
- `column_metadata` — column-level metadata
- `kpi_metadata` — KPI definitions (missing certification columns — add in G1)
- `vw_business_metadata_current` — view joining all metadata tables; downstream consumers read this

### Data Agent
`pbi/Enercare Governance Agent.DataAgent/` — already configured. Do not overwrite.

### Archive Purview Scripts (adapt, do not rewrite from scratch)
`archive/original/purview/06_purview_push_descriptions.py` — asset/column description push
`archive/original/purview/07_purview_register_lineage.py` — lineage registration
`archive/original/purview/ai_gap_fill.py` — AI description drafting

---

## Metadata Write-Back Approach — TMDL Git Pipeline (NOT sempy_labs)

The repo uses a **git-based TMDL pipeline** for semantic model write-back. This is the
answer to Christopher Dingle's question about TOM alternatives.

```
lh_metadata (vw_business_metadata_current)
    ↓  nb_04_generate_tmdl.py reads this view
    ↓  renders updated TMDL for each table file
    ↓  commits changes to pbi/BrookfieldEnercare.SemanticModel/definition/tables/
    ↓  Fabric Source Control sync applies changes to the live semantic model
```

- **Target directory**: `pbi/BrookfieldEnercare.SemanticModel/definition/tables/`
- **One file per table**: `dim_customer.tmdl`, `fct_billing.tmdl`, etc.
- **No XMLA endpoint needed. No Windows VM. No TOM CLR.**
- When generating TMDL, preserve all existing `lineageTag`, `sourceLineageTag`,
  `annotation`, and `partition` blocks — only inject/update `description` fields.

---

## The Build Backlog — docs/design-gap-analysis.md

This file IS the authoritative task list. When generating code, reference gap IDs:

| Gap | Priority | Status | Build target |
|---|---|---|---|
| G1 | P1 | 🟡 In Progress | Extend lh_metadata schema |
| G2 | P1 | 🟡 In Progress | Seed kpi_metadata with all KPIs |
| G3 | P1 | 🔴 Not Started | nb_04_generate_tmdl.py |
| G4 | P2 | 🔴 Not Started | ai_metadata + Copilot AI prep |
| G5 | P2 | ⏸ Blocked | Standalone Copilot tenant settings |
| G6 | P2 | 🔴 Not Started | nb_05_purview_push.py |
| G7 | P3 | 🔴 Not Started | nb_06_purview_lineage.py |
| G8 | P2 | 🔴 Not Started | nb_07_ai_gap_fill.py |
| G9 | P3 | 🔴 Not Started | Steward approval workflow |
| G10 | P3 | 🔴 Not Started | Ontology layer |
| G11 | P4 | ⏸ Blocked | B2C chatbot (EARB pending) |

---

## Non-Negotiable Constraints

1. **No secrets in this repo.** All credentials via environment variables sourced from
   Key Vault at runtime. Never hardcode `client_secret`, `api_key`, `access_token`,
   `PURVIEW_SECRET`, `SQL_PASSWORD`. Use `# TODO: load from Key Vault` placeholders.
2. **Fabric mirroring cap = 1,000 tables.** Enercare has 1,912. Keep mirror scope to
   `dw_inbnd_t` + selected `dw_t` tables (~300) when referencing production patterns.
3. **DEMO_MODE toggle.** Every new notebook must support `DEMO_MODE = True` (dry-run,
   prints payloads) and `DEMO_MODE = False` (live execution). Match the pattern in nb_02.
4. **lh_metadata is the single source of truth.** Descriptions, KPI definitions, AI
   instructions, verified answers all originate here and propagate downstream via pipelines.
5. **Only IsCertified = 1 KPIs propagate** to the semantic model and Purview glossary.

---

## Enercare Domain Terminology

- **PP** = Protection Plan (HVAC_PLAN, WH_RENTAL_PLAN)
- **MRR** = Monthly Recurring Revenue
- **FCR** = First Contact Resolution (call center KPI)
- **CSAT** = Customer Satisfaction Score (post-call IVR, 1–5 scale)
- **SLA Breach** = service technician missed committed time window
- **Source systems**: Clarify (CRM/field service), Zuora (billing), NetSuite (NS), CP360 (Customer 360)
- **Billing systems**: ZUORA, NS, CLARIFY (all three exist in prod — hence KPI inconsistency)

---

## Code Style

- All notebooks: Fabric PySpark (synapse_pyspark kernel), cell-by-cell with `# CELL **` separators
- Use `spark.sql(...)` for Delta reads; `df.write.format("delta").saveAsTable(...)` for writes
- Auth in scripts: `from azure.identity import DefaultAzureCredential` — never hardcode
- Purview API: `pyapacheatlas` — adapt patterns from `archive/original/purview/`
- Print a summary row count after every table write
- Match existing column naming: `IsDraft`, `IsCertified`, `DefinitionHash`, `AssetName`, `ColumnName`

---

## Context Files (always check before generating)
- `context/kpi-definitions.json` — 5 call center KPIs with full definitions
- `context/enercare-schemas.json` — actual table/column inventory (existing + additive CC layer)
- `context/data-gen-config.json` — synthetic data distributions
- `context/purview-type-defs.json` — Purview Atlas custom types
- `context/api-endpoints.json` — Fabric + Purview API endpoint patterns
