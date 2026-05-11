# Brookfield Enercare — Fabric Governance Solution

Collaboration workspace for building a Microsoft Fabric-native data governance and AI-grounding
solution for Brookfield Enercare. The project demonstrates a repeatable pattern for automated
governance at an energy services company: from structured metadata extraction through a governed
lakehouse, to AI-ready semantic model annotations that power Copilot and a natural-language
Data Agent.

---

## What the Demo Exposes

This solution is a **working end-to-end governance demo** that a collaborator or customer can run
entirely inside a Fabric workspace — no SQL Server required. It demonstrates:

| Capability | How it works |
|---|---|
| **Structured metadata extraction** | SQL views annotated with `@description`, `@kpi`, `@column`, `@sensitivity` tags — parsed by nb_02 into a governed Delta lakehouse |
| **Power BI Direct Lake semantic model** | Star schema built by nb_03, published as a TMDL semantic model with 12 DAX measures covering MRR, churn, SLA, warranty |
| **AI-grounded Copilot answers** | nb_04 injects table/column descriptions into the live semantic model via Fabric REST API; nb_05 pushes verified Q&A pairs into the `PBI_AI_Instructions` annotation |
| **Certified KPI governance** | KPIs flow from SQL header → lh_metadata → IsCertified gate → semantic model and Copilot grounding |
| **Natural-language Data Agent** | Enercare Data Agent queries the BrookfieldEnercare semantic model — answers questions like "what is our FCR?" or "show me SLA breach rate by technician" using certified KPI definitions |
| **Purview integration (planned)** | Metadata in lh_metadata is structured and ready for Atlas entity push, lineage registration, and business glossary population |

---

## Development Stages

### Stage 1 — Demo Environment ✅
Set up the Fabric workspace with synthetic Enercare data and a governed metadata lakehouse.

- Inline PySpark data loader for 7 source tables (no SQL Server dependency)
- Realistic Ontario energy services data: customers, contracts, equipment, service requests, billing
- `lh_enercare_demo` and `lh_metadata` lakehouses live in Fabric workspace

### Stage 2 — Metadata Pipeline ✅
Extract structured governance metadata from SQL view header comments into Delta tables.

- 5-phase extraction pipeline: parse headers → write to Delta → build views → preview Purview payloads
- Produces: `asset_metadata`, `column_metadata`, `kpi_metadata`, sensitivity/owner/lineage tables
- DEMO_MODE flag: dry-run previews all operations before writing

### Stage 3 — Star Schema + Semantic Model ✅
Build a Power BI Direct Lake semantic model on top of a proper star schema.

- 5 dimension tables + 3 fact tables built from source tables via nb_03
- TMDL semantic model checked in to git: relationships, DAX measures, Direct Lake datasource
- 12 DAX measures: Total MRR, New MRR, Churned MRR, Net MRR Change, SLA Compliance Rate,
  Warranty Coverage Rate, Active Customer Count, Avg Lifetime Value, Avg Tenure, and more

### Stage 4 — Extended Metadata Schema + AI Grounding ✅
Extend `lh_metadata` with AI-ready governance structures and inject descriptions into the live
semantic model via Fabric REST API.

- nb_04a extends kpi_metadata (IsCertified, Version, LinkedKPICode) and creates ai_metadata
- nb_04 reads descriptions from lh_metadata, fetches TMDL via REST API, injects table/column
  descriptions and `PBI_AI_Instructions` annotation, pushes back to semantic model
- nb_05 reads verified Q&A pairs from ai_metadata and rebuilds the annotation to include
  `VERIFIED Q&A: Q: {question} -> {answer}` blocks for Copilot grounding

### Stage 5 — Purview & Ontology (In Design)
Register governed assets, lineage, and glossary terms in Microsoft Purview.

- Atlas entity push from `lh_metadata` asset/column descriptions
- Column-level sensitivity classification propagation
- End-to-end lineage: SQL views → OneLake Delta → semantic model
- Business glossary population from KPI definitions

---

## Architecture

```
SQL Server / source systems
        │
        │  Structured header comments (@asset_type, @description,
        │  @owner, @sensitivity, @kpi, @column, @upstream …)
        │
        ▼
┌─────────────────────────────────────────────┐
│  nb_01_setup_demo_environment               │  Loads 7 source tables into
│  (Fabric Notebook — PySpark)                │  lh_enercare_demo
└──────────────────┬──────────────────────────┘
                   │
        ┌──────────┴──────────────────┐
        ▼                             ▼
┌───────────────────┐    ┌────────────────────────────┐
│  lh_enercare_demo │    │  lh_metadata               │
│                   │◄───│                            │
│  Source tables    │    │  asset_metadata            │
│  Star schema      │    │  column_metadata           │
│  (dim_*, fct_*)   │    │  kpi_metadata (certified)  │
└────────┬──────────┘    │  ai_metadata               │
         │               │  sensitivity_classification │
         │               │  data_lineage              │
         │               │  vw_business_metadata_     │
         │               │    current (unified view)  │
         │               └────────────┬───────────────┘
         │                            │
         ▼                            ▼
┌──────────────────────────────────────────────────────┐
│  BrookfieldEnercare Semantic Model (Direct Lake)     │
│  8 tables, 11 relationships, 12 DAX measures         │
│                                                      │
│  nb_04 → injects table/column descriptions via TMDL  │
│  nb_05 → injects verified Q&A into                  │
│          PBI_AI_Instructions annotation              │
└─────────────────────┬────────────────────────────────┘
                       │
         ┌─────────────┴──────────────────┐
         ▼                                ▼
┌──────────────────┐       ┌──────────────────────────────┐
│  Power BI Report │       │  Enercare Data Agent         │
│  (Direct Lake)   │       │  (AI Data Agent — NL queries │
└──────────────────┘       │   over semantic model;       │
                           │   FCR, CSAT, MRR, SLA)       │
                           └──────────────────────────────┘
                                          │
                                          ▼  (planned)
                           ┌──────────────────────────────┐
                           │  Microsoft Purview           │
                           │  - Atlas entities            │
                           │  - Sensitivity classifications│
                           │  - Lineage                   │
                           │  - Business glossary         │
                           └──────────────────────────────┘
```

---

## Notebook Reference

All notebooks live in `pbi/` (Fabric workspace sync) and share a **`DEMO_MODE` flag**:
- `DEMO_MODE = True` — dry-run: prints what would happen, no writes to Delta or REST API
- `DEMO_MODE = False` — live: executes all operations

> **nb_01 has no DEMO_MODE** — it only writes to the demo lakehouse (`lh_enercare_demo`)
> using `CREATE OR REPLACE` semantics. Running it again resets demo data to baseline.

### nb_01 — Setup Demo Environment
**Purpose:** Load synthetic Enercare source data into `lh_enercare_demo`.

| Feature | Detail |
|---|---|
| Delta table creation | 7 tables via inline PySpark (no SQL Server required) |
| Data volume | 50 customers, 56 service accounts, 10 products, 38 equipment, 68 contracts, 30 service requests, ~300 billing transactions |
| Idempotent | `CREATE OR REPLACE TABLE` — safe to re-run to reset demo state |
| Validation | Final cell prints row counts for all 7 tables |

**Run before:** nb_02, nb_03

---

### nb_02 — Metadata Pipeline Demo
**Purpose:** Extract governance metadata from SQL view header comments and write to `lh_metadata`.

| Feature | Detail |
|---|---|
| Header parsing | Regex extraction of `@description`, `@owner`, `@steward`, `@domain`, `@sensitivity`, `@kpi`, `@column`, `@upstream`, `@grain` tags |
| Delta writes | Populates `asset_metadata`, `column_metadata`, `kpi_metadata`, `sensitivity_classification`, `data_owners`, `data_lineage` |
| Unified view | Creates `vw_business_metadata` as a queryable governance surface |
| Purview preview | Builds Apache Atlas JSON payloads (dry-run by default — swap in credentials to push live) |
| DEMO_MODE | `True` = parse + preview only; `False` = writes all Delta tables |
| Production path | Swap `SQL_MODULES` dict for live JDBC read from `sys.sql_modules`; uncomment Purview credentials |

**Run before:** nb_03, nb_04a

---

### nb_03 — Power BI Star Schema
**Purpose:** Build a governed star schema in `lh_enercare_demo` for Direct Lake consumption.

| Feature | Detail |
|---|---|
| Dimension tables | `dim_date` (2014–2026), `dim_customer`, `dim_product`, `dim_equipment`, `dim_service_account` |
| Fact tables | `fct_billing`, `fct_service_request`, `fct_contract_month` (month-spine join) |
| Computed columns | `IsSlaBreachFlag`, `DaysToComplete`, `IsNew`, `IsChurn`, `IsUnderWarranty`, `AgeYears`, `FSA` |
| Date keys | Integer `YYYYMMDD` keys on all fact tables — joins to `dim_date[DateKey]` |
| Validation | Final cell prints row counts for all 8 star schema tables |

**Run before:** semantic model can be published/refreshed in Fabric

---

### nb_04a — Extend Metadata Schema
**Purpose:** Extend `lh_metadata` schema with AI-governance structures needed by nb_04 and nb_05.

| Feature | Detail |
|---|---|
| kpi_metadata extension | Adds: `KPICode`, `LinkedTableName`, `LinkedMeasureName`, `IsCertified`, `CertifiedBy`, `CertifiedDate`, `BusinessDefinition`, `Version`, `LastUpdatedDate`, `LastUpdatedBy` |
| IsCertified gate | Only KPIs with `IsCertified = 1` propagate to TMDL and Copilot grounding |
| ai_metadata table | New table: `RecordType` (`ai_instruction` / `verified_answer`), `TriggerText`, `ResponseText`, `LinkedKPICode`, `IsDraft` |
| Seed data | Pre-loads 3 AI instruction rows and 13 verified Q&A pairs for FCR, CSAT, PP Renewal Rate |
| View rebuild | Drops and recreates `vw_business_metadata_current` with unified 4-branch UNION ALL schema across all metadata tables |
| Idempotent DDL | Column existence check before ADD COLUMNS; ghost catalog entry handling for ai_metadata |
| DEMO_MODE | `True` = prints all SQL statements; `False` = executes DDL and DML |

**Run before:** nb_04, nb_05

---

### nb_04 — Generate TMDL (Metadata Write-Back)
**Purpose:** Read descriptions and AI instructions from `lh_metadata`, fetch the live TMDL via
Fabric REST API, inject metadata, and push back to the semantic model.

| Feature | Detail |
|---|---|
| Metadata read | Queries `vw_business_metadata_current` for table descriptions, column descriptions, and AI instructions |
| IsCertified gate | Only `IsCertified = 1` KPIs from `kpi_metadata` are included in the summary |
| Fabric REST API | `POST /semanticModels/{id}/getDefinition` (LRO with 202 → poll pattern) |
| TMDL injection | `inject_table_description` — inserts after `sourceLineageTag`; `inject_column_description` — inserts after `sourceColumn`; `inject_ai_instructions` — sets `PBI_AI_Instructions` annotation in model.tmdl |
| Ref table sync | Auto-adds missing `ref table` entries to model.tmdl for any tables present in TMDL but not yet referenced |
| Write-back | `POST /semanticModels/{id}/updateDefinition` — pushes all TMDL parts back (also LRO) |
| DEMO_MODE | `True` = dry-run prints injection plan per table; `False` = pushes live to semantic model |

**Run after:** nb_04a  **Run before:** nb_05 (for initial AI instructions baseline)

---

### nb_05 — Push Verified Q&A Answers
**Purpose:** Build an enhanced `PBI_AI_Instructions` annotation that includes both AI grounding
instructions and verified Q&A pairs, then push to the semantic model.

| Feature | Detail |
|---|---|
| Metadata read | Reads all `IsDraft = 0` rows from `ai_metadata`, split by `RecordType` |
| Annotation format | `{instructions} \| VERIFIED Q&A: Q: {TriggerText} -> {ResponseText}` — pairs joined with ` \| ` |
| Truncation | Truncates at clean ` \| ` boundary if annotation exceeds 3800 chars (Copilot annotation limit) |
| Minimal diff | Only `definition/model.tmdl` is modified — fastest push, no table TMDL changes |
| Coverage summary | Prints Q&A count grouped by `LinkedKPICode` |
| DEMO_MODE | `True` = prints full annotation preview + char count; `False` = pushes live |

**Run after:** nb_04a

---

## Run Order

```
nb_01  →  nb_02  →  nb_03  →  nb_04a  →  nb_04  →  nb_05
  │          │         │          │          │          │
Setup     Extract    Star      Extend     Inject     Inject
demo      metadata   schema    schema +   TMDL       verified
data      to         to        AI meta    descriptions Q&A to
          lh_meta    lh_enercare           + AI       Copilot
                     _demo                instructions
```

nb_02 and nb_03 can run in parallel after nb_01.
nb_04 and nb_05 can run independently after nb_04a.

---

## Current State

| Area | Status |
|---|---|
| Demo environment (`lh_enercare_demo`) | Live — 7 source tables, full star schema |
| Star schema | 5 dimensions + 3 facts, Direct Lake semantic model, 12 DAX measures |
| Metadata pipeline (`lh_metadata`) | Live — asset descriptions, column definitions, certified KPIs, AI metadata |
| TMDL description injection | Live — nb_04 pushes table/column descriptions via Fabric REST API |
| Copilot AI grounding | Live — PBI_AI_Instructions annotation set with instructions + verified Q&A |
| Governance Data Agent | Live — queries star schema + metadata lakehouses via natural language |
| Purview integration | In design — Atlas entity push not yet implemented |
| Ontology model | Not yet started |

---

## Repository Structure

```
/
├── demo/                              Dev copies + SQL seed data
│   ├── sql/
│   │   ├── 00_demo_schema_and_headers.sql     T-SQL schema + views with header convention
│   │   └── 01_demo_seed_data.sql              Seed data INSERT statements
│   └── README.md                     Demo-specific run instructions
│
├── pbi/                               Fabric workspace sync (branch: enercare, folder: /pbi)
│   ├── nb_01_setup_demo_environment.Notebook/   Source table loader
│   ├── nb_02_metadata_pipeline_demo.Notebook/   Governance metadata extractor
│   ├── nb_03_pbi_star_schema.Notebook/          Star schema builder
│   ├── nb_04a_extend_metadata_schema.Notebook/  Schema extension + AI metadata seeder
│   ├── nb_04_generate_tmdl.Notebook/            TMDL description injector (Fabric REST API)
│   ├── nb_05_push_qa_verified_answers.Notebook/ Copilot verified Q&A annotation pusher
│   ├── BrookfieldEnercare.SemanticModel/        Direct Lake semantic model (TMDL)
│   ├── BrookfieldEnercare.Report/               Power BI report
│   ├── lh_enercare_demo.Lakehouse/              Demo data lakehouse
│   ├── lh_metadata.Lakehouse/                   Governance metadata lakehouse
│   ├── Enercare Data Agent.DataAgent/           AI agent (NL queries over semantic model)
│   └── nb_05_push_qa_verified_answers.Notebook/ Pushes verified Q&A to PBI_AI_Instructions
│
└── sql/
    └── 02_extract_from_modules.sql    T-SQL metadata extractor (SQL Server path)
```

> **Git integration:** The Fabric workspace syncs to the `enercare` branch.
> Push changes here → sync in Fabric via **Source control → Update all**.
> Commit workspace changes back via **Source control → Commit**.

---

## Demo Data Model

Modelled on an Ontario residential/commercial energy services company.

### Source Tables (`lh_enercare_demo`)

| Table | Rows | Description |
|---|---|---|
| `customers` | 50 | Residential (40), Commercial (5), MUR (5) — Ontario cities |
| `service_accounts` | 56 | Natural Gas, HVAC, Water Heater, Electricity |
| `products` | 10 | Rentals, protection plans, smart home |
| `contracts` | 68 | Active, Cancelled, Expired |
| `equipment_registry` | 38 | Water heaters, furnaces, AC, heat pumps, thermostats |
| `service_requests` | 30 | Completed, InProgress, Open — with SLA breach flags |
| `billing_transactions` | ~300 | Jan–Jun 2024 monthly charges + payments |

### Star Schema (`lh_enercare_demo`)

| Layer | Tables |
|---|---|
| Dimensions | `dim_date`, `dim_customer`, `dim_product`, `dim_equipment`, `dim_service_account` |
| Facts | `fct_billing`, `fct_service_request`, `fct_contract_month` |

Key computed columns: `IsSlaBreachFlag`, `DaysToComplete`, `IsNew`, `IsChurn`,
`IsUnderWarranty`, `AgeYears`, `FSA`.

### Metadata Tables (`lh_metadata`)

| Table | Description |
|---|---|
| `asset_metadata` | Table/view descriptions, owner, steward, domain, sensitivity, DefinitionHash |
| `column_metadata` | Column descriptions per asset |
| `kpi_metadata` | KPI definitions with `IsCertified` gate, `LinkedMeasureName`, `BusinessDefinition` |
| `ai_metadata` | AI grounding instructions (`ai_instruction`) and verified Q&A pairs (`verified_answer`) |
| `sensitivity_classification` | Column-level sensitivity tags |
| `data_owners` | Owner and steward assignments per asset |
| `data_lineage` | Upstream dependency graph |
| `vw_business_metadata_current` | Unified view across all tables — single query surface for nb_04/nb_05 |

---

## Metadata Header Convention

Source SQL objects carry structured comments that nb_02 parses:

```sql
-- @asset_type    : view
-- @description   : Customer 360 — lifetime value, tenure, SLA exposure
-- @owner         : analytics@enercare.ca
-- @sensitivity   : Internal
-- @kpi           : ActiveCustomerCount | count(customer_id) WHERE status='Active'
-- @column        : CustomerKey | Surrogate key | Internal
-- @upstream      : customers, service_accounts, contracts
```

Supported tags: `@asset_type`, `@description`, `@owner`, `@steward`, `@domain`,
`@grain`, `@refresh`, `@sensitivity`, `@glossary`, `@upstream`, `@column`, `@kpi`, `@notes`

---

## DEMO_MODE Convention

All notebooks except nb_01 respect a `DEMO_MODE` flag at the top of Cell 1:

| Value | Behaviour |
|---|---|
| `True` (default) | Dry-run — prints SQL statements, annotation previews, or injection plans. No Delta writes, no REST API calls. Safe to run at any time. |
| `False` | Live — executes all operations: writes Delta tables, alters schemas, calls Fabric REST API to push TMDL changes. |

Change `DEMO_MODE = True` to `DEMO_MODE = False` and re-run when ready to apply.

---

## Getting Started (New Collaborator)

### Prerequisites
- Access to the Fabric workspace `Enercare` (workspace ID: `795ce5db-7ea0-4a7c-ba64-e27c9fb568f4`)
- Git access to this repository (branch: `enercare`)
- Power BI Desktop (July 2023+) to view the semantic model locally via `pbi/BrookfieldEnercare.pbip`

### Sync workspace from git
In the Fabric workspace: **Source control → Update all**

### Full pipeline run (fresh start)
1. `nb_01` — loads all 7 source tables into `lh_enercare_demo`
2. `nb_02` — extracts governance metadata into `lh_metadata` (set `DEMO_MODE = False`)
3. `nb_03` — builds star schema in `lh_enercare_demo`
4. `nb_04a` — extends `lh_metadata` schema and seeds AI metadata (set `DEMO_MODE = False`)
5. `nb_04` — injects TMDL descriptions into semantic model (set `DEMO_MODE = False`)
6. `nb_05` — pushes verified Q&A annotation to semantic model (set `DEMO_MODE = False`)

The semantic model and Data Agent are live after step 3. Steps 4–6 add AI grounding.

### Verifying Copilot grounding (after nb_05)
Ask Copilot in the Power BI report or Data Agent:
- *"What is our FCR?"* → should return First Contact Resolution definition
- *"What is our CSAT score?"* → should return CSAT definition and context
- *"What is our PP renewal rate?"* → should return Protection Plan renewal definition

---

## Planned: Purview & Ontology

The next development phase uses the populated `lh_metadata` tables as the source of truth
for Purview registration and ontology generation.

**Purview targets:**
- Register lakehouse tables as Atlas `DataSet` entities with business descriptions
- Push column-level sensitivity classifications from `sensitivity_classification`
- Create lineage edges: source SQL objects → OneLake Delta tables → semantic model
- Populate business glossary terms from `kpi_metadata` and `column_metadata`

**Ontology targets:**
- Define entity types for the Enercare domain (Customer, ServiceAccount, Equipment,
  Contract, ServiceEvent, BillingEvent)
- Map star schema tables to ontology classes
- Export ontology compatible with Purview custom type definitions

**Notebooks to build:**
- `nb_06_purview_register_assets` — Atlas entity push from `lh_metadata`
- `nb_07_purview_lineage` — lineage registration
- `nb_08_ontology_export` — ontology artifact generation

---

## Key Contacts

| Role | Name |
|---|---|
| Project lead | Sean Kelley (Microsoft) |
| Original scaffold | Ajay (Microsoft PG) |
