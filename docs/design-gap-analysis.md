# Enercare - Build Gap Analysis (vNext)

**Last updated:** 2026-05-20  
**Branch:** `enercare` | **File:** `docs/design-gap-analysis.md`  
**Owners:** Sean Kelley (Microsoft), Brian Lung (Microsoft)  
**Stakeholders:** Christopher Dingle (VP Data & Analytics), Ranbir Singh, Alison, Ajay

> **What changed in this version**  
> This document replaces the earlier OneLake-first framing with the broader build now requested:  
> `sub1` = Microsoft Fabric workspace and semantic model plane  
> `sub2` = Azure SQL Server source system populated with synthetic Enercare data  
> `sub3` = Microsoft Purview governance plane  
> The build continues to reuse the notebooks, semantic model, and metadata scaffolding already created, but the target architecture now centers on Azure SQL mirroring and Purview publication.

---

## Executive Direction

The Enercare demo is no longer just a Fabric-native metadata prototype. The target build is now an end-to-end cross-subscription architecture that:

1. Publishes synthetic Enercare source data into **Azure SQL Server in sub2**.
2. Mirrors that SQL source into **Microsoft Fabric in sub1**.
3. Applies metadata and governance logic to Fabric assets and the semantic model.
4. Deploys **Purview in sub3** for scanning, catalog publication, glossary, and lineage.
5. Uses **Purview as the published metadata system of record** for governed discovery.

### Non-negotiable design decisions

- **Do not assume source extended properties exist.** They do not.
- **Do not make source SQL extended properties a prerequisite for the build.** Metadata must be derived from the existing notebooks, SQL artifacts, and curated metadata tables.
- **Keep the current Fabric assets.** The existing notebooks, `lh_metadata` scaffolding, semantic model, and connectivity work remain useful and should be adapted rather than discarded.
- **Keep semantic model descriptions.** Even if Purview becomes the catalog system of record, Copilot and Fabric Data Agents still need metadata propagated into the semantic model.
- **Purview becomes the governed catalog endpoint.** `lh_metadata` remains a working/staging store for authoring, curation, and propagation, but not the final catalog authority.
- **Define semantic write-back as a hybrid pattern, not a single tool choice.** The baseline repo pattern remains Git-backed TMDL and Fabric Items API updates. SemPy Labs is an allowed integration for targeted semantic-model write-backs when XMLA is enabled, but it is not the primary required deployment path.

---

## Current State Summary

### What is already working

- Synthetic Enercare data generation exists in the Fabric notebooks.
- The `lh_metadata` lakehouse schema and supporting metadata tables are scaffolded.
- The BrookfieldEnercare semantic model exists and is under Git-backed TMDL control.
- Fabric outbound private connectivity from the Enercare workspace to `sqlserver-sk2` is implemented through a managed private endpoint.
- JDBC connectivity from the Fabric notebook to `sqldemo` succeeded.
- The validation user `seankelley@MngEnvMCAP660444.onmicrosoft.com` was provisioned in `sqldemo` as `EXTERNAL_USER` for the smoke test.
- Temporary public access used for the admin step was removed; the SQL server is back to private-only access.
- The `sub3` Purview account is now deployed as `Purview-West3` in `AzureWest3-RG` (`westus3`, subscription `bde41857-48c2-4eb5-9959-208f768deafb`).

### What is not yet built

- The synthetic dataset is not yet established as the authoritative **Azure SQL source** in sub2.
- Fabric mirroring from the sub2 SQL source is not yet configured as the primary ingestion path.
- Purview in sub3 is deployed, but scanning of the SQL/Fabric estate is not yet configured.
- Purview publication, glossary, and lineage registration are not yet implemented.
- The earlier gap structure does not yet represent the new three-subscription target state.

---

## Quick Status - Revised Build Gaps

| # | Gap | Priority | Status | Owner |
|---|---|---|---|---|
| G1 | Cross-subscription target architecture and environment alignment | P1 | 🟡 In Progress | Sean |
| G2 | Azure SQL source system in sub2 | P1 | 🔴 Not Started | Sean |
| G3 | Synthetic data publication from notebooks into Azure SQL | P1 | 🔴 Not Started | Sean |
| G4 | Fabric mirroring from sub2 SQL into sub1 | P1 | 🔴 Not Started | Ajay |
| G5 | Metadata extraction and working metadata store alignment | P1 | 🟡 In Progress | Sean |
| G6 | Semantic model metadata write-back and Copilot grounding | P1 | 🟡 In Progress | Ajay / Sean |
| G7 | Purview deployment in sub3 | P1 | 🟡 In Progress | Alison |
| G8 | Purview scans, catalog publication, and glossary | P1 | 🔴 Not Started | Alison |
| G9 | Lineage registration from SQL to Fabric to semantic model | P2 | 🔴 Not Started | Ajay / Alison |
| G10 | Steward workflow and AI-assisted metadata drafting | P3 | 🔴 Not Started | Alison / Sean |
| G11 | Optional ontology and B2C extensions | P4 | ⏸ Blocked / Deferred | Ajay / Sean |

---

## Target Architecture - vNext

### Subscription roles

| Subscription | Role | Target assets |
|---|---|---|
| `sub1` | Fabric build, mirror landing, Lakehouse, semantic model, Copilot, Data Agents | Fabric workspace, lakehouses, notebooks, mirrored DB, semantic model |
| `sub2` | Authoritative SQL source for the demo | Azure SQL server, `sqldemo`, source views/procs/tables |
| `sub3` | Governance and catalog plane | Microsoft Purview account, scans, glossary, lineage, classifications |

### End-state flow

1. Notebooks 1-2 generate synthetic Enercare data.
2. That data is loaded into **Azure SQL in sub2** as the demo source system.
3. **Fabric Mirroring** in sub1 ingests the SQL source into OneLake.
4. Metadata is authored or staged in working stores (`lh_metadata`, notebook-driven tables, extracted SQL definitions).
5. Metadata is propagated to the **semantic model** so Copilot and Data Agents can use it.
6. **Purview in sub3** scans SQL and Fabric assets, receives curated metadata and lineage, and becomes the published catalog system of record.

### Metadata publication model

| Layer | Purpose | System-of-record role |
|---|---|---|
| Azure SQL source objects | Business source and scan target | Source data authority |
| `lh_metadata` in Fabric | Working metadata cache/staging/curation | Not final catalog authority |
| Fabric semantic model | Consumption surface for Copilot and Data Agents | Published consumer surface |
| Purview | Catalog, glossary, lineage, discoverability | **Published metadata system of record** |

### Semantic model write-back definition

| Path | Role | Status in solution |
|---|---|---|
| Git-backed TMDL + Fabric Items API | Primary path for model descriptions, AI instructions, verified answers, and repeatable source-controlled updates | **Required baseline** |
| SemPy / SemPy Labs integration | Optional targeted write-back path for column and measure descriptions where XMLA-enabled model operations are useful | **Included as optional integration, not baseline** |

This resolves the current repo inconsistency: the solution definition should not say "no SemPy" globally. It should say "no SemPy as the only or primary write-back mechanism." SemPy Labs remains in-scope for focused semantic-model updates.

---

## Gap Details

## G1 - Cross-Subscription Target Architecture And Environment Alignment

**Priority:** P1  
**Goal:** Lock the subscription topology and connection model so the build stops drifting between prototype assumptions and the new production-style design.  
**Status:** 🟡 In Progress

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G1-1 | Confirm sub1/sub2/sub3 roles and named resources | 🟡 In Progress | Sean | Fabric = sub1, SQL = sub2, Purview = sub3; Purview account = `Purview-West3` |
| G1-2 | Record target resource names, regions, RGs, and identities in this document | 🟡 In Progress | Sean | Captured workspace, SQL server, and Purview account; scan identity still pending |
| G1-3 | Keep Fabric managed private endpoint pattern for sub1 -> sub2 SQL access | 🟢 Done | Sean | `sqlserver-sk2-mpe` validated |
| G1-4 | Confirm Entra app / MI ownership model for Purview and scanning | 🔴 Not Started | Alison | Needed before G7/G8 |
| G1-5 | Update all build docs to reflect Purview-as-catalog and SQL-mirroring-first architecture | 🔴 Not Started | Sean | This file is the first step |

---

## G2 - Azure SQL Source System In sub2

**Priority:** P1  
**Goal:** Establish the Azure SQL database in sub2 as the authoritative source for the mirrored demo.  
**Status:** 🟡 In Progress

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G2-1 | Finalize target SQL server and database in sub2 | 🟡 In Progress | Sean | Currently testing against `sqlserver-sk2` / `sqldemo` |
| G2-2 | Create or confirm source schema for synthetic Enercare tables in Azure SQL | 🟡 In Progress | Sean | Initial DDL captured in `sql/02_sub2_sql_source_schema.sql` for the seven source tables consumed by the current star schema |
| G2-3 | Define which views/procs will carry business semantics for metadata extraction | 🔴 Not Started | Sean + Christopher | Needed for metadata path |
| G2-4 | Decide whether metadata helper tables also live in SQL or remain Fabric-side only | 🔴 Not Started | Sean | Keep simple unless Purview scan benefits from SQL-side metadata objects |
| G2-5 | Validate SQL source shape is stable enough to be mirrored | 🔴 Not Started | Sean | Before G4 |

---

## G3 - Synthetic Data Publication From Notebooks Into Azure SQL

**Priority:** P1  
**Goal:** Reuse the current synthetic-data notebooks, but publish their output into Azure SQL in sub2 instead of treating Fabric-only tables as the long-term source.  
**Status:** 🟡 In Progress

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G3-1 | Map notebook-generated entities to Azure SQL target tables | 🟡 In Progress | Sean | Mapping note added in `docs/sub2-sql-source-mapping.md`; first cut is the seven source tables read by `nb_02_pbi_star_schema.py` |
| G3-2 | Build load/export notebook or script from Fabric outputs to Azure SQL | 🟡 In Progress | Sean | Initial publish workflow added as source mirror in `demo/fabric/nb_05a_publish_synthetic_data_to_sql.py` and Git sync notebook in `pbi/nb_05a_publish_synthetic_data_to_sql.Notebook/` |
| G3-3 | Seed sub2 SQL with current synthetic dataset | 🔴 Not Started | Sean | Core new requirement |
| G3-4 | Reconcile row counts and keys between notebook outputs and SQL source | 🔴 Not Started | Sean | Validation gate |
| G3-5 | Document rerun behavior for regenerating and republishing synthetic data | 🔴 Not Started | Sean | Needed for demo repeatability |

---

## G4 - Fabric Mirroring From sub2 SQL Into sub1

**Priority:** P1  
**Goal:** Mirror the SQL source into Fabric so the solution demonstrates the intended SQL mirroring architecture instead of a Fabric-only seeded path.  
**Status:** 🔴 Not Started

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G4-1 | Create mirrored Azure SQL Database item in Fabric for the sub2 source | 🔴 Not Started | Ajay | Primary architecture objective |
| G4-2 | Validate mirrored tables land in OneLake with expected names and types | 🔴 Not Started | Ajay | |
| G4-3 | Decide how mirrored tables coexist with current demo lakehouse tables | 🔴 Not Started | Sean + Ajay | Avoid destroying current model |
| G4-4 | Update star schema / downstream notebooks to read mirrored source where appropriate | 🔴 Not Started | Ajay | Incremental migration |
| G4-5 | Validate end-to-end refresh and freshness behavior | 🔴 Not Started | Ajay | Required for demo narrative |

---

## G5 - Metadata Extraction And Working Metadata Store Alignment

**Priority:** P1  
**Goal:** Preserve the metadata work already done, but realign it so metadata can be derived from SQL artifacts and then staged for downstream propagation.  
**Status:** 🟡 In Progress

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G5-1 | Keep `lh_metadata` as the working metadata cache/staging store | 🟡 In Progress | Sean | No longer the final catalog authority |
| G5-2 | Reconcile current metadata schema against the README build recommendations | 🔴 Not Started | Sean | Align table purposes and names |
| G5-3 | Define metadata extraction approach from SQL views/procs or sidecar conventions | 🔴 Not Started | Sean | No dependency on source extended properties |
| G5-4 | Update notebook extractor logic to support SQL-source-first metadata | 🔴 Not Started | Sean | Extend current notebook path |
| G5-5 | Distinguish curated metadata rows from AI draft rows and scan-derived rows | 🔴 Not Started | Sean | Needed before Purview publication |

---

## G6 - Semantic Model Metadata Write-Back And Copilot Grounding

**Priority:** P1  
**Goal:** Continue using semantic model descriptions, AI instructions, and verified answers so Fabric Copilot and Data Agents have a trustworthy consumption surface even when Purview becomes the catalog authority.  
**Status:** 🟡 In Progress

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G6-1 | Preserve current Git-backed TMDL and Fabric Items API write-back approach as the baseline path | 🟡 In Progress | Ajay | Do not regress existing progress |
| G6-2 | Update `nb_04_generate_tmdl.py` for mirrored-source naming where needed | 🔴 Not Started | Ajay | Align to new architecture |
| G6-3 | Keep AI instructions and verified Q&A delivery into the semantic model | 🟡 In Progress | Sean | Existing scaffolding already present; stays on Items API/TMDL path |
| G6-4 | Add SemPy Labs integration point for targeted column/measure description write-backs where XMLA-enabled operations are beneficial | 🔴 Not Started | Ajay / Sean | Optional integration, not the required baseline |
| G6-5 | Validate that TMDL/Items API and SemPy write-backs do not conflict and remain consistent with Purview publication | 🔴 Not Started | Sean + Alison | No drift between model and catalog |
| G6-6 | Confirm XMLA/capacity prerequisites if SemPy Labs will be used in this environment | 🔴 Not Started | Sean | Required only for SemPy path |
| G6-7 | Maintain `nb_05b_test_sql_connectivity` as a smoke test for private SQL access | 🟢 Done | Sean | End-to-end JDBC test succeeded |

---

## G7 - Purview Deployment In sub3

**Priority:** P1  
**Goal:** Stand up the dedicated Purview plane in sub3 and prepare it to scan both the SQL source and the Fabric estate.  
**Status:** 🟡 In Progress

### Working design decision for G7

For the current Enercare architecture, the Purview networking model should use **private scanning paths first**, not a broad "all networks" posture.

- Use Purview managed virtual network and private ingestion connectivity for scanning private Azure sources where possible.
- Do **not** treat the Purview account private endpoint as a required day-one step for this build.
- Add Purview account and portal private endpoints only if and when we decide to set Purview public network access to `Deny` for admin/API access.
- Keep the design focused on privately reaching the Azure SQL source in `sub2`; do not create extra private endpoints just because the Purview account wizard offers them.

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G7-1 | Deploy Purview account in sub3 | 🟢 Done | Alison | Deployed as `Purview-West3` in `AzureWest3-RG` (`westus3`), subscription `bde41857-48c2-4eb5-9959-208f768deafb` |
| G7-2 | Configure networking and trusted access for SQL and Fabric scanning | 🟡 In Progress | Alison | Preferred pattern: Purview managed VNet/private ingestion for private SQL scanning; defer Purview account/portal private endpoints unless public access will be denied |
| G7-3 | Register scan identities / service principals and required roles | 🟡 In Progress | Alison | Define the scan identity model for Azure SQL in sub2: prefer managed identity where supported; otherwise use a dedicated Entra app/service principal and provision least-privilege SQL read metadata access |
| G7-4 | Confirm Fabric tenant integration with Purview | 🔴 Not Started | Alison | |
| G7-5 | Capture Purview account details, regions, and scan boundaries in this doc | 🟡 In Progress | Alison | Account details captured; initial scan boundary is private Azure SQL in sub2 and later mirrored Fabric assets in sub1 |

---

## G8 - Purview Scans, Catalog Publication, And Glossary

**Priority:** P1  
**Goal:** Make Purview the published metadata system of record by scanning SQL and Fabric assets, then enriching catalog entries with the curated metadata prepared by the solution.  
**Status:** 🔴 Not Started

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G8-1 | Scan Azure SQL source objects in sub2 | 🔴 Not Started | Alison | Tables, views, procedures where supported |
| G8-2 | Scan Fabric mirrored assets, lakehouses, and semantic model surfaces | 🔴 Not Started | Alison | |
| G8-3 | Build Purview push notebook/script to enrich scanned assets with curated descriptions | 🔴 Not Started | Alison | Adapt archive scripts as needed |
| G8-4 | Publish certified KPI terms into Purview glossary | 🔴 Not Started | Alison | |
| G8-5 | Define conflict rule when Purview scan metadata and curated metadata disagree | 🔴 Not Started | Sean + Alison | Purview remains published authority |
| G8-6 | Validate that Purview becomes the discoverability endpoint for business users | 🔴 Not Started | Alison + Christopher | Acceptance test |

---

## G9 - Lineage Registration From SQL To Fabric To Semantic Model

**Priority:** P2  
**Goal:** Register lineage that starts at the SQL source in sub2 and flows through mirrored Fabric assets into the semantic model and report layer.  
**Status:** 🔴 Not Started

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G9-1 | Update `lineage_edges` modeling for SQL source -> mirrored table -> semantic model path | 🔴 Not Started | Ajay | Existing table can be reused |
| G9-2 | Build Purview lineage registration notebook/script | 🔴 Not Started | Ajay | Adapt archive lineage script |
| G9-3 | Register at least one complete sample lineage chain for demo | 🔴 Not Started | Ajay | Minimum viable scenario |
| G9-4 | Validate lineage graph in Purview for a representative KPI/column | 🔴 Not Started | Alison + Christopher | Acceptance test |

---

## G10 - Steward Workflow And AI-Assisted Metadata Drafting

**Priority:** P3  
**Goal:** Add the operational layer so humans can approve metadata drafts and certified definitions before they are published to Purview and the semantic model.  
**Status:** 🔴 Not Started

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G10-1 | Keep `IsDraft` / `IsCertified` workflow semantics in the working metadata store | 🟡 In Progress | Sean | Existing schema already points this way |
| G10-2 | Build steward review workflow for drafted descriptions and KPI certifications | 🔴 Not Started | Alison | Notebook first, app later |
| G10-3 | Reintroduce AI gap-fill only after SQL-source-first metadata path is stable | 🔴 Not Started | Sean + Ajay | Lower priority than topology shift |
| G10-4 | Define publication rules from approved metadata into Purview and semantic model | 🔴 Not Started | Sean + Alison | |

---

## G11 - Optional Ontology And B2C Extensions

**Priority:** P4  
**Goal:** Defer non-core items until the mirrored SQL + Purview governance path is working end-to-end.  
**Status:** ⏸ Blocked / Deferred

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G11-1 | Ontology layer for Enercare domain classes | 🔴 Not Started | Alison + Christopher | Only after Purview base path works |
| G11-2 | AI gap-fill at scale across sparse metadata | 🔴 Not Started | Ajay | Depends on G10 |
| G11-3 | B2C/customer support chatbot architecture | ⏸ Blocked | Ajay / Sean | Not part of the immediate build pivot |

---

## What Stays From The Current Build

The following assets remain valid and should be adapted, not removed:

- `demo/fabric/nb_01_setup_demo_environment.py`
- `demo/fabric/nb_03_metadata_pipeline_demo.py`
- `demo/fabric/nb_04a_extend_metadata_schema.py`
- `demo/fabric/nb_04_generate_tmdl.py`
- `pbi/BrookfieldEnercare.SemanticModel/definition/`
- `pbi/nb_05b_test_sql_connectivity.Notebook/`
- The `lh_metadata` lakehouse and its working metadata tables
- The Fabric managed private endpoint from the Enercare workspace to `sqlserver-sk2`

### Additional retained requirement

- SemPy Labs integration remains in-scope as a targeted semantic-model write-back option for column and measure descriptions. It should be defined as complementary to the TMDL/Items API baseline, not as a replacement for it.

### Explicitly retired assumptions

- OneLake is **not** the final metadata system of record for this build.
- Source SQL extended properties are **not** assumed to exist.
- The build should not depend on writing source SQL extended properties just to make the architecture work.

---

## Immediate Next Build Steps

1. Finalize the sub2 SQL source schema and publish the synthetic dataset into it.
2. Stand up Fabric mirroring from sub2 SQL into sub1.
3. Deploy Purview in sub3.
4. Repoint metadata tasks so Purview becomes the published catalog authority while semantic model write-back remains active for Copilot.
5. Rework demo sequencing so the narrative is: SQL source -> Mirroring -> Fabric model -> Purview governance.

---

## Acceptance Criteria For The Revised Build

- Synthetic Enercare source data exists in Azure SQL in sub2.
- Fabric mirrors that SQL source into sub1.
- The semantic model in Fabric contains curated descriptions and AI grounding content.
- Purview in sub3 scans both SQL and Fabric assets.
- Purview displays curated descriptions, glossary terms, and at least one validated lineage chain.
- The Fabric JDBC smoke-test notebook continues to validate private connectivity from the workspace to the sub2 SQL source.
