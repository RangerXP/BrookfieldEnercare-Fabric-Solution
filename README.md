# Brookfield Enercare — Fabric Governance Solution

Collaboration workspace for building a Microsoft Fabric-native data governance solution
for Brookfield Enercare. The project establishes a metadata pipeline that extracts
structured governance metadata from source systems and uses it to produce ontology
artifacts, Power BI semantic models, and Microsoft Purview assets.

---

## Project Goal

Demonstrate a repeatable pattern for automated governance at an energy services company:

1. Annotate source objects (SQL views/tables) with structured header comments
2. Extract metadata into a governed `lh_metadata` lakehouse
3. Build a Power BI Direct Lake semantic model + AI Data Agent on top of the star schema
4. **→ Next:** Generate ontology artifacts and register data assets, lineage, and
   column-level classifications in **Microsoft Purview** from the metadata pipeline

---

## Current State

| Area | Status |
|---|---|
| Demo environment (`lh_enercare_demo`) | Live in Fabric — 7 source tables, full star schema |
| Star schema | 5 dimensions + 3 facts, Direct Lake semantic model with 12 DAX measures |
| Metadata pipeline (`lh_metadata`) | Live — asset descriptions, column definitions, KPIs, owners, sensitivity |
| Governance Data Agent | Live — queries star schema + metadata lakehouses via natural language |
| Purview integration | In design — ontology and Atlas entity push not yet implemented |
| Ontology model | Not yet started |

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
│  nb_01_setup_demo_environment               │  Loads source tables into
│  (Fabric Notebook — PySpark)                │  lh_enercare_demo
└──────────────────┬──────────────────────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
┌───────────────┐    ┌────────────────────┐
│ lh_enercare   │    │   lh_metadata      │
│ _demo         │    │                    │
│               │    │  asset_metadata    │
│  Source tables│    │  column_metadata   │
│  Star schema  │    │  kpi_definitions   │
│  (dim_*, fct*)│    │  data_owners       │
└───────┬───────┘    │  sensitivity_class │
        │            │  data_lineage      │
        │            └────────┬───────────┘
        │                     │
        ▼                     ▼
┌──────────────────────────────────────────────┐
│  BrookfieldEnercare Semantic Model           │  Direct Lake — Power BI
│  (TMDL, 8 tables, 11 relationships,          │  + Governance Data Agent
│   12 DAX measures)                           │  (natural language queries)
└──────────────────────────────────────────────┘
        │
        ▼  (planned)
┌──────────────────────────────────────────────┐
│  Microsoft Purview                           │
│  - Data assets (Atlas entities)              │
│  - Column-level sensitivity classifications  │
│  - Lineage (source → lakehouse → semantic    │
│    model)                                    │
│  - Business glossary / ontology terms        │
└──────────────────────────────────────────────┘
```

---

## Repository Structure

```
/
├── demo/                          Dev copies of notebooks + SQL seed data
│   ├── fabric/
│   │   ├── nb_01_setup_demo_environment.py    Source table loader
│   │   ├── nb_02_pbi_star_schema.py           Star schema builder
│   │   └── nb_03_metadata_pipeline_demo.py    Metadata pipeline
│   └── sql/
│       ├── 00_demo_schema_and_headers.sql     T-SQL schema with header convention
│       └── 01_demo_seed_data.sql              Seed data (INSERT statements)
│
├── metadata/                      Fabric workspace sync (branch: enercare, folder: /)
│   ├── lh_enercare_demo.Lakehouse/            Demo data lakehouse
│   ├── lh_metadata.Lakehouse/                 Governance metadata lakehouse
│   ├── nb_01_setup_demo_environment.Notebook/ Loads source tables
│   ├── nb_02_metadata_pipeline_demo.Notebook/ Extracts metadata → lh_metadata
│   ├── nb_03_pbi_star_schema.Notebook/        Builds star schema tables
│   └── Enercare Governance Agent.DataAgent/   AI agent over star schema + metadata
│
└── pbi/                           Fabric workspace sync (branch: enercare, folder: /pbi)
    ├── BrookfieldEnercare.SemanticModel/      Direct Lake semantic model (TMDL)
    ├── BrookfieldEnercare.Report/             Power BI report
    ├── Enercare Governance Agent.DataAgent/   AI agent (pbi workspace copy)
    ├── lh_enercare_demo.Lakehouse/
    └── lh_metadata.Lakehouse/
```

> **Git integration:** The Fabric workspace syncs to the `enercare` branch.
> The `main` branch mirrors `enercare` and is kept in sync via merge.
> The `archive/original` branch preserves the original project scaffold from the
> initial engagement handoff.

---

## Demo Data Model

Modelled on an Ontario residential/commercial energy services company.

| Table | Rows | Description |
|---|---|---|
| `customers` | 50 | Residential (40), Commercial (5), MUR (5) |
| `service_accounts` | 56 | Natural Gas, HVAC, Water Heater, Electricity |
| `products` | 10 | Rentals, protection plans, smart home |
| `contracts` | 68 | Active, Cancelled, Expired |
| `equipment_registry` | 38 | Water heaters, furnaces, AC, heat pumps, thermostats |
| `service_requests` | 30 | Completed, InProgress, Open — with SLA breach flags |
| `billing_transactions` | ~300 | Jan–Jun 2024 monthly charges + payments |

### Star Schema

| Layer | Tables |
|---|---|
| Dimensions | `dim_date`, `dim_customer`, `dim_product`, `dim_equipment`, `dim_service_account` |
| Facts | `fct_billing`, `fct_service_request`, `fct_contract_month` |

Key computed columns: `IsSlaBreachFlag`, `DaysToComplete`, `IsNew`, `IsChurn`,
`IsUnderWarranty`, `AgeYears`, `FSA`.

---

## Metadata Header Convention

Source SQL objects are annotated with structured comments that the pipeline parses:

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

## Planned: Purview & Ontology Work

The next development phase uses the populated `lh_metadata` tables as the source of
truth for Purview registration and ontology generation.

**Purview targets:**
- Register lakehouse tables as Atlas `DataSet` entities with business descriptions
- Push column-level sensitivity classifications from `sensitivity_classification`
- Create lineage edges: source SQL objects → OneLake Delta tables → semantic model
- Populate business glossary terms from `kpi_definitions` and `column_metadata`

**Ontology targets:**
- Define entity types for the Enercare domain (Customer, ServiceAccount, Equipment,
  Contract, ServiceEvent, BillingEvent)
- Map star schema tables to ontology classes
- Export ontology in a format compatible with Purview custom type definitions

**Reference notebooks (to be built):**
- `nb_04_purview_register_assets.py` — Atlas entity push from `lh_metadata`
- `nb_05_purview_lineage.py` — lineage registration
- `nb_06_ontology_export.py` — ontology artifact generation

---

## Getting Started (New Collaborator)

### Prerequisites
- Access to the Fabric workspace `Enercare` (workspace ID: `795ce5db-7ea0-4a7c-ba64-e27c9fb568f4`)
- Git access to this repository
- Power BI Desktop (July 2023+) to view the semantic model locally via `pbi/BrookfieldEnercare.pbip`

### Fabric workspace sync
The workspace is connected to this repo (`enercare` branch). To pull latest changes
into the workspace: **Source control → Update all**.

To push workspace changes back to git: **Source control → Commit**.

### Running the pipeline from scratch
1. Run `nb_01_setup_demo_environment` — loads all 7 source tables into `lh_enercare_demo`
2. Run `nb_02_metadata_pipeline_demo` — extracts governance metadata into `lh_metadata`
3. Run `nb_03_pbi_star_schema` — builds the star schema (dim_* and fct_* tables)
4. The semantic model and Data Agent are live immediately after step 3

---

## Key Contacts

| Role | Name |
|---|---|
| Project lead | Sean Kelley (Microsoft) |
| Original scaffold | Ajay (Microsoft PG) |
