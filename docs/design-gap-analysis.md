# Enercare Fabric Governance — Design Gap Analysis & Updated Roadmap

**Date:** 2026-05-05  
**Inputs:** Original package (Ajay/PG), current `/pbi` build state, customer meeting 2026-05-05  
**Audience:** Sean Kelley (Microsoft), Brian Lung (Microsoft), Christopher Dingle (VP Data & Analytics, Enercare)

---

## 1. Prioritized Inputs from the 2026-05-05 Customer Meeting

The following are ranked by impact on the design, not by meeting order.

### Priority 1 — Blockers / Immediate Design Constraints

**P1-A: SemPy cannot write back to semantic models (Christopher Dingle, confirmed)**
> "Read: SemPy is designed for reading semantic model metadata… Write operations require XMLA/TOM commands, which SemPy doesn't expose."

*Design implication:* The TOM/XMLA write-back path Ajay's package assumed (`05_apply_metadata_to_fabric.py`) requires either a Windows VM with `pythonnet` or an alternative mechanism. A Windows VM is "not so elegant." The git-based TMDL update path — already operational in this project — is the preferred alternative. See §4-C.

**P1-B: KPI inconsistency is the primary business driver**
> "Same KPI reported differently across business groups. Updates to logic not consistently propagated."

*Design implication:* `kpi_metadata` in `lh_metadata` must become the canonical store. KPI logic must be version-controlled and subject to business sign-off before propagation. The current `kpi_metadata` table has the right schema; it needs a certification/approval flag and a promotion pipeline.

**P1-C: Metadata sparsity — clean slate**
> "Very, very naive. Sparse (business terms especially)."

*Design implication:* AI gap-fill (Ajay's `ai_gap_fill.py`) is not a nice-to-have — it is required to bootstrap the catalog. This moves from Priority 4 in the original plan to Priority 1. The Azure OpenAI dependency should be replaced with Fabric-native AI Functions to avoid external credential management.

---

### Priority 2 — Near-Term Requirements (Next 2–4 Weeks)

**P2-A: "Prep data for AI" must be applied to the semantic model**
> "Copilot requires standardized semantic model and good metadata behind it."

The four components of "prep data for AI" are: (1) large model storage enabled, (2) simplified schema, (3) verified answers, (4) AI instructions. Only AI instructions are currently addressed (via the Data Agent). Verified answers and model-level AI instructions on the semantic model are not yet configured.

**P2-B: Standalone Copilot enablement**
> "Standalone Copilot can restrict to approved models. Desire to avoid exposing all 300 models."

Tenant settings for Standalone Copilot need to be enabled and scoped to the `BrookfieldEnercare` semantic model. This is a Fabric admin task, not a pipeline task, but it is a dependency for demonstrating the full Copilot flow.

**P2-C: Metadata architecture must resolve the "where does it live" question**
> "We want to build this in the right place… we're in a circular loop."

The meeting explicitly left the canonical metadata store unresolved. The `lh_metadata` OneLake approach (Ajay's design, implemented in our pipeline) is the correct answer. This document needs to be the definitive response to Brian's action item: *"Provide an update on alternatives for storing and managing metadata in Fabric, including options for data lineage and integration with Purview."*

---

### Priority 3 — Medium-Term (1–2 Months)

**P3-A: Lineage metadata for impact analysis**
> "Impact analysis: what breaks when a KPI changes? Hundreds of reports built on separate models."

Purview lineage edges (table → model → report) are needed for impact analysis. Without this, changing a KPI definition has unknown blast radius.

**P3-B: Business glossary with ownership**
> "Centralized KPI definitions with governance and business sign-off."

Purview business glossary terms need to be created from `kpi_metadata`, with `Owner` and `Steward` mapped to glossary term owners. Change requests route through the approval workflow.

**P3-C: AI metadata domain — verified answers and AI instructions per model**
> "Verified answers / predefined responses. Semantic understanding (business terms mapped to data)."

This is a new metadata domain not fully addressed by Ajay's original design. The `lh_metadata` schema needs an `ai_metadata` table for verified Q&A pairs and per-model AI instruction blocks.

---

### Priority 4 — Longer-Term / Dependent on IT Approval

**P4-A: B2C chatbot (structured + unstructured)**
> "A chatbot that can answer customer support queries by integrating structured data from Power BI and unstructured data like call transcripts."

Requires Fabric Data Agent + AI Search + Copilot Studio integration. Blocked on IT/legal approval for cross-region data processing in Canada.

**P4-B: Real-time analytics (15-minute refresh)**
> "Move from daily to near real-time dashboard updates, aiming for 15-minute intervals."

Requires Mirroring or Eventstream. Not a metadata pipeline concern, but the metadata pipeline must capture refresh cadence in `operational_metadata` to support this.

---

## 2. Compare and Contrast

### What Ajay's Package Designed

A six-phase pipeline from SQL source → OneLake metadata hub → Fabric surfaces → Purview:

| Phase | Description | Script |
|---|---|---|
| 0 | `@tag` header convention in SQL views/procs | `00_metadata_header_convention.sql` |
| 1 | T-SQL extractor → `meta.*` in source DB + Azure OpenAI gap-fill + steward approval | `02_extract_from_modules.sql`, `ai_gap_fill.py` |
| 2 | JDBC replication → `lh_metadata` Delta (MERGE + SHA-256 hash, Delta time travel) | `03_replicate_meta_to_onelake.py` |
| 3 | Fabric Mirroring for zero-ETL data landing | (portal config) |
| 4 | Apply to Fabric: Delta comments + Warehouse XP + TOM push to semantic model | `05_apply_metadata_to_fabric.py` |
| 5 | Purview: descriptions + glossary + sensitivity + custom lineage edges | `06_purview_push_descriptions.py`, `07_purview_register_lineage.py` |
| 6 | AI consumers: Copilot for PBI, Data Agents grounded on `lh_metadata`, Purview Q&A | — |

The original design did **not** include: star schema, TMDL semantic model, Power BI report, Data Agent with custom instructions, git-managed PBIP project, or an AI metadata domain.

### What We Have Built

| Component | Status | Gap vs. Original |
|---|---|---|
| `@tag` header convention | Done | None |
| Python metadata extractor (nb_02) | Done — demo mode | Needs JDBC to real SQL; currently inline Python |
| `lh_metadata` — `asset_metadata`, `column_metadata`, `kpi_metadata` | Done | Missing: `ai_metadata`, `sensitivity_classification`, `data_owners`, `lineage_edges` tables |
| `lh_metadata.vw_business_metadata_current` | Done | Needs AI metadata columns added |
| Star schema (`dim_*`, `fct_*`) | Done — **not in original** | New capability |
| Direct Lake semantic model (TMDL, 11 relationships, 12 measures) | Done — **not in original** | New capability |
| Power BI report | Done — **not in original** | New capability |
| Governance Data Agent | Done — **not in original** | New capability |
| Delta column comments | Dry run only | Need to activate |
| TOM/XMLA push to semantic model | Not implemented | Replace with TMDL git-update pipeline (see §4-C) |
| Purview push — descriptions | Dry run only | Need SP credentials + activation |
| Purview push — Fabric qualified names | Not started | Need to add `fabric_lakehouse_table_column` push |
| Purview lineage | Not started | nb_05 needed |
| AI gap-fill | Not adapted | Rewrite for Fabric-native AI Functions |
| Steward approval workflow | Not started | `IsDraft` flag exists; no UI |
| Drift detection | Not started | `DefinitionHash` column exists; no comparison job |
| Ontology model | Not started | New work; required for Purview custom types |
| Verified answers / AI instructions on semantic model | Not started | New metadata domain from meeting |
| Sensitivity classifications | Not started | `@sensitivity` tag parsed; not applied as MIP label |
| Fabric Mirroring | Not started | nb_01 uses inline Python data |

### Net Assessment

The current build is **ahead of Ajay's original on the analytics layer** (star schema + semantic model + Data Agent) and **behind on the governance propagation layer** (Purview push, lineage, TOM write-back). The meeting adds a new domain — **AI metadata** (verified answers, AI instructions, "prep data for AI") — that neither the original design nor the current build fully addresses.

---

## 3. Updated Architecture

The revised architecture incorporates four changes from the meeting:

1. **Git-based TMDL update replaces TOM/XMLA** for semantic model metadata write-back
2. **AI metadata domain** added as a first-class layer in `lh_metadata`
3. **Copilot 3-tier model** (User → Data Agent → Semantic Model → Verified Answer) is the AI consumer architecture
4. **Standalone Copilot governance** (curated model list, tenant settings) added as a control plane

```
                    ┌──────────────────────────────────────────────┐
                    │  SOURCE (Azure SQL DB / Fabric Lakehouse)     │
                    │                                              │
                    │  Views + stored procs with @tag headers      │
                    │  OR sidecar YAML (DBAs who prefer clean SQL) │
                    └────────────────────┬─────────────────────────┘
                                         │
                              nb_01: Extract metadata
                              (Python parser, @tag → structured rows)
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────┐
│  lh_metadata  —  CANONICAL METADATA HUB (OneLake)                     │
│                                                                        │
│  asset_metadata        ← business name, description, owner, steward   │
│  column_metadata       ← column descriptions, sensitivity             │
│  kpi_metadata          ← KPI formula, unit, owner, IsCertified        │
│  ai_metadata    [NEW]  ← verified answers, AI instructions per model  │
│  ontology_classes [NEW]← entity types, class hierarchy                │
│  ontology_relationships [NEW] ← entity-to-entity relationships        │
│  lineage_edges  [NEW]  ← source → lakehouse → model → report edges    │
│  data_owners           ← owner + steward per domain                   │
│  sensitivity_class     ← MIP label mappings                           │
│                                                                        │
│  vw_business_metadata_current  ← wide view, all consumers read here   │
└──────────┬──────────────────────┬────────────────────────────┬─────────┘
           │                      │                            │
     ┌─────▼──────┐        ┌──────▼──────┐           ┌────────▼────────┐
     │  Phase 4a  │        │  Phase 4b   │           │   Phase 4c      │
     │  Delta     │        │  TMDL Git   │           │   Purview Push  │
     │  column    │        │  update     │           │   (Phase 5)     │
     │  comments  │        │  pipeline   │           │                 │
     └─────┬──────┘        └──────┬──────┘           └────────┬────────┘
           │                      │                            │
           ▼                      ▼                            ▼
   lh_enercare_demo      /pbi TMDL files             Microsoft Purview
   Delta tables with     in git → Fabric             - Asset descriptions
   column COMMENTs       Source Control              - Glossary terms
   (Copilot for          Update syncs to             - Sensitivity labels
    Data Engineering)    semantic model              - Lineage edges
                         (no TOM needed)
                                │
                         ┌──────▼───────────────────────────────┐
                         │  BrookfieldEnercare Semantic Model   │
                         │  (Direct Lake, TMDL)                 │
                         │                                      │
                         │  Tables: dim_*, fct_*                │
                         │  Measures: 12 DAX (+ KPI-driven new) │
                         │  Descriptions: from lh_metadata      │
                         │  AI instructions: from ai_metadata   │
                         │  Verified answers: from ai_metadata  │
                         └──────────────┬───────────────────────┘
                                        │
               ┌────────────────────────┼───────────────────────┐
               ▼                        ▼                       ▼
     ┌──────────────────┐   ┌───────────────────────┐  ┌──────────────┐
     │  Power BI Report │   │  Governance Data Agent│  │  Standalone  │
     │  (Copilot for    │   │  (lh_metadata +       │  │  Copilot     │
     │   Power BI)      │   │   star schema)        │  │  (curated    │
     │                  │   │                       │  │  model list) │
     └──────────────────┘   └───────────────────────┘  └──────────────┘
                                        │
                            ┌───────────▼───────────┐
                            │  3-Tier Copilot Model  │
                            │  User Question         │
                            │    ↓                   │
                            │  Data Agent            │
                            │    ↓                   │
                            │  Semantic Model        │
                            │    ↓                   │
                            │  Verified Answer       │
                            └───────────────────────┘
```

### Key Architecture Decision: Git-Based TMDL as the Semantic Model Write Path

Christopher's follow-up email confirmed the TOM/XMLA constraint. The git-managed TMDL files in `/pbi/BrookfieldEnercare.SemanticModel/definition/tables/` are already how the semantic model is maintained in this project. The write-back pipeline becomes:

```
lh_metadata.vw_business_metadata_current
    → nb_04_generate_tmdl.py (Python: reads metadata, renders TMDL templates)
    → git push to enercare branch
    → Fabric Source Control Update (auto-sync or API-triggered)
    → Semantic model descriptions updated — no TOM, no Windows VM
```

This is the answer to Brian's action item and Christopher's question about "more friendly Fabric Python notebook alternatives."

---

## 4. Gap-Closing Steps (Revised and Expanded)

Steps are sequenced to deliver value incrementally, with the current `/pbi` build as the starting point.

---

### Phase A — Activate Existing Code (1–2 weeks)

**A1: Apply Delta column comments to `lh_enercare_demo` tables**

The DDL is already generated by `nb_02_metadata_pipeline_demo`. Flip `DEMO_MODE = False` for the column comment block. Confirms the pipeline end-to-end before tackling Purview.

**A2: Wire Purview service principal + push asset descriptions**

Register an app in Entra ID → grant `Data Curator` on the Purview account → store credentials in Fabric Notebook environment variables. Set `DEMO_MODE = False` for the Purview push block. The Atlas payloads (mssql qualified names) are already built in nb_02.

**A3: Extend Purview push to Fabric Lakehouse qualified names**

Add a second pass in the Purview push block for `fabric_lakehouse_table_column` qualifiedNames covering the star schema tables. Template:
```
fabric://<workspace-id>/lh_enercare_demo/<table>/<column>
```

**A4: Enable "Prep data for AI" on the BrookfieldEnercare semantic model**

In Fabric: open the semantic model → Settings → Q&A → enable large model storage. Add AI instructions to the model using the Data Agent `stage_config.json` pattern (same format, applied to the semantic model). Source the instructions from `lh_metadata.ai_metadata` once that table exists.

---

### Phase B — Extend `lh_metadata` Schema (2–3 weeks)

**B1: Add `ai_metadata` table**

New table to store verified Q&A pairs and per-model AI instruction blocks — the AI metadata domain identified in the meeting:

```
ai_metadata (
    AiMetadataId    INT,
    AssetId         INT,          -- FK to asset_metadata
    MetadataType    STRING,       -- 'ai_instruction' | 'verified_answer' | 'term_mapping'
    QuestionPattern STRING,       -- for verified_answer: the trigger question
    Answer          STRING,       -- for verified_answer: the authoritative response
    Instruction     STRING,       -- for ai_instruction: the instruction text
    IsCertified     INT,          -- 1 = business-signed-off, 0 = draft
    Owner           STRING,
    LastUpdatedUtc  STRING
)
```

Populate from existing Data Agent `stage_config.json` AI instructions as the seed. This table becomes the source of truth for AI instructions across all models.

**B2: Add `kpi_metadata.IsCertified` flag and version columns**

Meeting explicitly requires "business sign-off on KPI definitions and updates." Extend existing `kpi_metadata` with:
- `IsCertified` INT — 1 = approved by business owner, 0 = draft
- `CertifiedBy` STRING
- `CertifiedDate` STRING
- `Version` INT — increment on each change
- `PreviousFormula` STRING — for rollback/audit

**B3: Add `lineage_edges` table**

Needed for Purview lineage registration and impact analysis:

```
lineage_edges (
    EdgeId          INT,
    SourceQName     STRING,   -- Purview qualifiedName of upstream asset
    TargetQName     STRING,   -- Purview qualifiedName of downstream asset
    ProcessType     STRING,   -- 'mirroring' | 'notebook' | 'dataflow' | 'direct_lake'
    ProcessName     STRING,   -- e.g. 'nb_03_pbi_star_schema'
    LastRegistered  STRING
)
```

**B4: Add `ontology_classes` and `ontology_relationships` tables**

```
ontology_classes (
    ClassId         INT,
    ClassName       STRING,   -- e.g. 'Customer', 'ServiceAccount', 'Equipment'
    Description     STRING,
    FabricTable     STRING,   -- e.g. 'dim_customer'
    PurviewTypeName STRING    -- Atlas EntityDef typeName
)

ontology_relationships (
    RelId           INT,
    FromClassId     INT,
    ToClassId       INT,
    RelationshipType STRING,  -- e.g. 'has', 'subscribes_to', 'owns'
    Cardinality     STRING    -- '1:N', 'N:1', 'N:N'
)
```

Seed with: Customer → has → ServiceAccount → has → Equipment; Customer → has → Contract → has → BillingEvent; ServiceAccount → generates → ServiceEvent.

---

### Phase C — TMDL Pipeline (Replaces TOM/XMLA) (3–4 weeks)

**C1: Build `nb_04_generate_tmdl.py`**

This is the answer to Christopher's TOM question. A Fabric PySpark notebook that:

1. Reads `lh_metadata.vw_business_metadata_current` + `ai_metadata`
2. For each table in the semantic model, renders a TMDL file using Python string templates
3. Injects descriptions into `column` blocks and `measure` blocks
4. Injects AI instructions from `ai_metadata` into the model-level `linguisticMetadata` block
5. Writes the rendered `.tmdl` files to a `/pbi/BrookfieldEnercare.SemanticModel/definition/tables/` path via the Fabric Lakehouse Files API or directly via OneLake DFS
6. Triggers a git commit via the Fabric Git API (or documents the manual Source Control → Update step)

This pipeline turns the TMDL files from hand-maintained artifacts into generated outputs — metadata-driven, no TOM, no Windows VM.

**C2: Add verified answers to the semantic model**

Fabric's "prep data for AI" supports a `verifiedAnswers` JSON block per semantic model. Populate from `ai_metadata WHERE MetadataType = 'verified_answer'` using the TMDL pipeline above.

---

### Phase D — Purview Lineage + Glossary (4–6 weeks)

**D1: Build `nb_05_purview_lineage.py`**

Adapt `07_purview_register_lineage.py` for the Fabric model. Register three lineage edges per asset using Atlas Process entities:

- `nb_01` (Process) → lh_enercare_demo source tables (output)
- `nb_03` (Process) → star schema dim/fct tables (output), source tables (input)
- Direct Lake connection (Process) → semantic model columns (output), star schema tables (input)

This gives Purview end-to-end column-level lineage from source SQL → OneLake → semantic model.

**D2: Create Purview business glossary from `kpi_metadata`**

For each `kpi_metadata` row with `IsCertified = 1`, create a Purview glossary term using the `pyapacheatlas` `GlossaryClient`. Map `Owner` to `contacts.Expert` and `Steward` to `contacts.Owner`. Assign terms to the corresponding `powerbi_dataset_measure` assets.

---

### Phase E — Ontology + Custom Purview Types (6–10 weeks)

**E1: Register custom Atlas `EntityDef` types**

Use the Purview Atlas API to register the entity types defined in `ontology_classes` as custom `EntityDef` entries. This makes Enercare-domain entities (`Customer`, `ServiceAccount`, `Equipment`, etc.) first-class types in the Purview catalog instead of generic `DataSet`.

**E2: Map assets to ontology classes**

Update the Purview push (Phase A2/A3) to use the `OntologyClass → PurviewTypeName` mapping. Lakehouse tables are registered under their domain type, not `mssql_table`.

**E3: Cross-ontology lineage**

Extend `lineage_edges` to capture ontology-class-level lineage (e.g., `Customer` entity is sourced from `customers` table, exposed in `dim_customer`, and surfaced via `dim_customer` in the semantic model).

---

### Phase F — Production Hardening (Parallel / Ongoing)

**F1: Replace nb_01 inline data with Fabric Mirroring**

Configure a Mirrored Azure SQL Database item pointing at the real Enercare source DB. Replace nb_01's inline Python lists with shortcuts to Mirrored Delta tables in `lh_enercare_demo`. All downstream notebooks (nb_02, nb_03) are unchanged.

**F2: AI gap-fill using Fabric-native AI Functions**

Replace `ai_gap_fill.py`'s external Azure OpenAI call with Fabric Spark SQL's `ai_generate_text()` function (no external credentials):

```python
spark.sql("""
    UPDATE lh_metadata.asset_metadata
    SET Description = ai_generate_text(
        CONCAT('Write a 2-sentence business description for a SQL view named ', ObjectName,
               ' in an energy services company. Output only the description text.'),
        named_struct('modelId', 'gpt-4o-mini')
    ),
    IsDraft = 1
    WHERE Description IS NULL AND IsDraft = 0
""")
```

**F3: Drift detection nightly job**

After each nb_02 run, compare `DefinitionHash` against the previous run. Where hash changed and `IsDraft = 0`, set `IsDraft = 1` (re-review required). Emit a summary to the Data Agent so stewards can ask "what metadata changed this week?"

**F4: Standalone Copilot enablement**

Fabric admin task: enable Standalone Copilot in tenant settings, scope to the `BrookfieldEnercare` semantic model and approved security group. Share Naunihal's enablement documentation with Christopher's team (follow-up action from meeting).

**F5: IT/legal approval for Fabric Data Agent cross-region**

Support Christopher/Naunihal in preparing the IT architecture review board deck. The cross-region data processing constraint is a legal/compliance matter specific to Canada; the technical architecture is unaffected.

---

## 5. Revised Roadmap Summary

```
PHASE A — Activate (Weeks 1–2)
  A1  Delta column comments live
  A2  Purview SP credentials + asset description push
  A3  Extend push to Fabric Lakehouse qualified names
  A4  "Prep data for AI" on BrookfieldEnercare semantic model

PHASE B — Extend lh_metadata Schema (Weeks 2–3)
  B1  ai_metadata table (verified answers + AI instructions)
  B2  kpi_metadata: IsCertified + version columns
  B3  lineage_edges table
  B4  ontology_classes + ontology_relationships tables

PHASE C — TMDL Pipeline / Semantic Model Write-Back (Weeks 3–4)
  C1  nb_04_generate_tmdl.py — metadata → TMDL files → git → Fabric sync
  C2  Verified answers injected into semantic model via TMDL

PHASE D — Purview Lineage + Glossary (Weeks 4–6)
  D1  nb_05_purview_lineage.py — Atlas Process entities, 3-tier lineage
  D2  Purview business glossary from kpi_metadata

PHASE E — Ontology (Weeks 6–10)
  E1  Register custom Atlas EntityDef types
  E2  Map assets to ontology classes in Purview push
  E3  Cross-ontology lineage

PHASE F — Production Hardening (Parallel / Ongoing)
  F1  Fabric Mirroring replaces inline data
  F2  AI gap-fill via Fabric-native ai_generate_text()
  F3  Drift detection nightly job
  F4  Standalone Copilot enablement (admin task)
  F5  IT/legal approval for Fabric Data Agent cross-region
```

---

## 6. Response to Meeting Action Items

### Brian / Sean action item: *"Provide an update on alternatives for storing and managing metadata in Fabric, including options for data lineage and integration with Purview, by end of week."*

**Answer:** `lh_metadata` (OneLake Delta) is the canonical store. All consumers — Copilot, Data Agents, Purview, TMDL pipeline — read from `lh_metadata.vw_business_metadata_current`. Metadata is authored once (via `@tag` headers in SQL or sidecar YAML), extracted by a Fabric notebook, and propagated in four directions:

1. **Delta column comments** on Lakehouse tables (Copilot for Data Engineering)
2. **TMDL git update pipeline** → semantic model descriptions + AI instructions (no TOM required)
3. **Purview Atlas push** → asset descriptions + glossary + sensitivity + lineage edges
4. **Data Agent grounding** → `lh_metadata` tables queried directly by the Governance Agent

For data lineage specifically: custom Atlas `Process` entities are registered via `pyapacheatlas` (nb_05). This covers source SQL view → Lakehouse table → semantic model column — three hops of column-level lineage in Purview.

### Christopher's question: *"More friendly Fabric Python notebook alternatives to TOM?"*

**Answer:** Yes. The git-managed TMDL files in `/pbi/BrookfieldEnercare.SemanticModel/definition/tables/` are the semantic model's source of truth in this project. `nb_04_generate_tmdl.py` will read `lh_metadata`, render updated TMDL files with descriptions and AI instructions, commit to the `enercare` git branch, and trigger a Fabric Source Control sync. No Windows VM, no TOM, no `pythonnet`. The trade-off vs TOM is that changes go through git (seconds to minutes) rather than in-memory (milliseconds) — acceptable for a metadata propagation pipeline that runs on a schedule.
