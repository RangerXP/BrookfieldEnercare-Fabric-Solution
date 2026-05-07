---
mode: agent
description: "G1 + G2: Extend lh_metadata schema and seed kpi_metadata with all certified KPIs"
tools: ["filesystem"]
---

# G1 + G2 — Extend lh_metadata Schema & Seed KPI Definitions

## What already exists (do not drop or recreate)
`lh_metadata` already has: `asset_metadata`, `column_metadata`, `kpi_metadata`, `vw_business_metadata_current`
See `#file:context/enercare-schemas.json` section `lh_metadata_existing_tables` for current column lists.

## Task 1 — Extend kpi_metadata (G1-3 + G2-1)

Write a Spark SQL migration cell to ADD these columns to the existing `kpi_metadata` Delta table.
Use `ALTER TABLE` — do not drop and recreate.

```sql
ALTER TABLE lh_metadata.kpi_metadata ADD COLUMNS (
    KPICode        STRING,
    IsCertified    INT     DEFAULT 0,
    Version        INT     DEFAULT 1,
    PreviousFormula STRING,
    CertifiedBy    STRING,
    CertifiedDate  DATE,
    TargetValue    DOUBLE,
    WarningThreshold DOUBLE,
    CriticalThreshold DOUBLE,
    UnitType       STRING  -- 'percentage' | 'score_1_to_5' | 'seconds' | 'currency' | 'count'
)
```

## Task 2 — Create new lh_metadata tables (G1-4, G1-5, G1-7)

Create three new Delta tables in `lh_metadata`. Use the schema from
`#file:context/enercare-schemas.json` section `section_b_call_center_extension.lh_metadata_new_tables`.

Tables to create:
- `lh_metadata.ai_metadata` — verified answers, AI instructions, term mappings
- `lh_metadata.data_owners` — owner/steward registry per domain
- `lh_metadata.lineage_edges` — source-to-target graph for Purview lineage

Format: Spark SQL `CREATE TABLE IF NOT EXISTS ... USING DELTA`

## Task 3 — Seed kpi_metadata with ALL KPIs (G2-2)

INSERT two sets of KPI rows into `lh_metadata.kpi_metadata`:

**Set A — 12 existing DAX measures** from `#file:context/enercare-schemas.json`
section `section_a_existing.star_schema_measures`. For each measure set:
- `IsCertified = 0` (pending business sign-off — correct default)
- `Domain` from the measures list
- `KPICode` = snake_case of the measure name (e.g., `total_mrr`, `sla_compliance_rate`)
- `Version = 1`

**Set B — 5 call center KPIs** from `#file:context/kpi-definitions.json`. For each:
- `IsCertified = 1` (pre-certified for demo)
- `CertifiedBy = 'Christopher Dingle'`
- `CertifiedDate = '2026-05-06'`
- Fill all columns: KPICode, formula → Formula, business_definition → Description,
  target_value → TargetValue, warning_threshold → WarningThreshold, unit → UnitType

## Task 4 — Seed ai_metadata with Copilot content (G1-4, G4)

INSERT rows into `lh_metadata.ai_metadata` for the 3 certified call center KPIs
that have verified answers (FCR, CSAT, PP_RNW_RATE) from `#file:context/kpi-definitions.json`:

For each KPI's `verified_answer_triggers` list, create one row with:
- `RecordType = 'verified_answer'`
- `TriggerText` = the trigger phrase
- `ResponseText` = the `answer_template` from kpi-definitions.json
- `LinkedKPICode` = the KPI code
- `IsDraft = 0` (these are pre-approved for demo)

Also INSERT 3 `ai_instruction` rows using content from
`#file:copilot/ai_instructions/model_ai_instructions.md` — one row per major section
(Business Context, Critical Terminology, KPI Definitions). `IsDraft = 0`.

## Task 5 — Update vw_business_metadata_current

Extend the existing view to JOIN with the new tables. Add:
- `UNION ALL` select from `ai_metadata` (RecordType, TriggerText, ResponseText)
- Include a `SourceTable` column on all branches so consumers know the origin

## Output file
Write all of the above as a single new notebook source file:
`demo/fabric/nb_04a_extend_metadata_schema.py`

Structure as Fabric notebook cells with `# CELL **` separators.
Include `DEMO_MODE = True` at the top — when True, print the ALTER/CREATE/INSERT
statements but do not execute; when False, execute.

Print a completion summary:
```
lh_metadata schema extension complete:
  kpi_metadata: 9 new columns added
  ai_metadata:  created (0 rows → seeded N rows)
  data_owners:  created
  lineage_edges: created
  kpi_metadata seeded: 17 KPIs (12 existing measures + 5 call center)
  ai_metadata seeded: N verified answers + 3 AI instructions
```

After writing the file, update `docs/design-gap-analysis.md`:
- G1-3: change status from `🔴 Not Started` to `🟢 Done`
- G1-4, G1-5, G1-7: change to `🟢 Done`
- G2-1, G2-2: change to `🟢 Done`
