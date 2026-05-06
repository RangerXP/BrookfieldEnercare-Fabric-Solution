# Enercare — Metadata Platform: Working Document

**Last updated:** 2026-05-05  
**Branch:** `enercare` | **File:** `docs/design-gap-analysis.md`  
**Owners:** Sean Kelley (Microsoft), Brian Lung (Microsoft)  
**Stakeholders:** Christopher Dingle (VP Data & Analytics), Ranbir Singh, Ci Zhu (Enercare)

> **How to use this document**  
> Each gap section contains discrete tasks. Update `Status` and `Owner` as work progresses.  
> Status values: `🔴 Not Started` · `🟡 In Progress` · `🟢 Done` · `⏸ Blocked`  
> Add notes under tasks as decisions are made. Commit changes to `enercare` branch.

---

## Quick Status — All Gaps

| # | Gap | Priority | Status | Owner |
|---|---|---|---|---|
| G1 | Canonical metadata store | P1 | 🟡 In Progress | Sean |
| G2 | Certified KPI definitions | P1 | 🟡 In Progress | Sean |
| G3 | Metadata write-back to semantic model | P1 | 🔴 Not Started | Sean |
| G4 | Copilot "prep data for AI" | P2 | 🔴 Not Started | Sean |
| G5 | Standalone Copilot governance | P2 | ⏸ Blocked | Naunihal |
| G6 | Purview integration (descriptions + glossary) | P2 | 🔴 Not Started | Sean |
| G7 | Lineage registration in Purview | P3 | 🔴 Not Started | Sean |
| G8 | AI gap-fill for sparse metadata | P2 | 🔴 Not Started | Sean |
| G9 | Steward approval workflow | P3 | 🔴 Not Started | TBD |
| G10 | Ontology layer | P3 | 🔴 Not Started | Sean + Christopher |
| G11 | B2C chatbot (structured + unstructured) | P4 | ⏸ Blocked | Jonson / Naunihal |

---

## Context: Why This Matters

Enercare has hundreds of purpose-built Power BI models with divergent KPI logic. Metadata is "very, very naive" — sparse, tribal, and unstored. Copilot accuracy depends entirely on the quality of metadata behind the semantic model. The north star: a small set of certified semantic models, enriched with business metadata, surfaced through Copilot and Data Agents, backed by a centralized metadata system (Purview + OneLake), and automated via pipelines.

**This document tracks the work required to get there.**

---

## G1 — Canonical Metadata Store

**Priority:** P1 — everything downstream depends on this  
**Goal:** Single queryable hub (`lh_metadata` in OneLake) feeding Copilot, Purview, Data Agents, and the semantic model. Metadata is authored once and propagated everywhere.  
**Status:** 🟡 In Progress — `lh_metadata` exists with 3 tables; schema needs extension

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G1-1 | `asset_metadata` table — verify schema covers all required fields (owner, steward, domain, sensitivity, IsDraft, DefinitionHash) | 🟢 Done | Sean | Exists in current build |
| G1-2 | `column_metadata` table — verify schema | 🟢 Done | Sean | Exists in current build |
| G1-3 | `kpi_metadata` table — add `IsCertified`, `Version`, `PreviousFormula`, `CertifiedBy`, `CertifiedDate` columns | 🔴 Not Started | Sean | Currently missing certification fields |
| G1-4 | `ai_metadata` table — new; stores verified answers, AI instructions, term mappings per model | 🔴 Not Started | Sean | New domain identified in meeting |
| G1-5 | `data_owners` table — owner + steward registry per domain | 🔴 Not Started | Sean | |
| G1-6 | `sensitivity_classification` table — sensitivity label mappings | 🔴 Not Started | Sean | |
| G1-7 | `lineage_edges` table — source → target transformation graph | 🔴 Not Started | Sean | Prerequisite for G7 |
| G1-8 | `ontology_classes` + `ontology_relationships` tables | 🔴 Not Started | Sean + Christopher | Prerequisite for G10 |
| G1-9 | Extend `vw_business_metadata_current` to include new tables | 🔴 Not Started | Sean | After G1-3 through G1-8 complete |
| G1-10 | Update nb_02 extractor to populate new table columns | 🔴 Not Started | Sean | After schema changes done |

---

## G2 — Certified KPI Definitions

**Priority:** P1 — primary business driver stated in meeting  
**Goal:** Business stakeholders own and certify KPI definitions. Logic is version-controlled. Changes require approval before propagating to the semantic model or Purview.  
**Status:** 🟡 In Progress — `kpi_metadata` table exists; certification workflow missing

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G2-1 | Add `IsCertified`, `Version`, `PreviousFormula`, `CertifiedBy`, `CertifiedDate` to `kpi_metadata` (see G1-3) | 🔴 Not Started | Sean | |
| G2-2 | Seed `kpi_metadata` with existing 12 DAX measures from BrookfieldEnercare semantic model | 🔴 Not Started | Sean | Starting point for business review |
| G2-3 | Define KPI ownership — agree with Christopher/Ranbir on which business owner certifies each domain's KPIs | 🔴 Not Started | Christopher / Ranbir | Business decision |
| G2-4 | Propagation rule: only `IsCertified = 1` KPIs promoted to semantic model and Purview glossary | 🔴 Not Started | Sean | Gate in nb_04 and nb_05 |
| G2-5 | Version increment logic: when KPI formula changes, capture old formula in `PreviousFormula`, bump `Version`, reset `IsCertified = 0` | 🔴 Not Started | Sean | Triggers re-certification |

---

## G3 — Metadata Write-Back to Semantic Model

**Priority:** P1 — unblocks Copilot configuration and Purview descriptions  
**Goal:** Descriptions, AI instructions, and verified answers from `lh_metadata` are automatically applied to the BrookfieldEnercare semantic model — without TOM, XMLA, or a Windows VM.  
**Status:** 🔴 Not Started  
**Approach:** Git-based TMDL pipeline. The semantic model is maintained as TMDL files in git. A Fabric notebook renders updated TMDL from `lh_metadata`, commits to the `enercare` branch, and Fabric Source Control sync applies the changes.

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G3-1 | Design TMDL template for table/column description injection | 🔴 Not Started | Sean | Template per table file in `/pbi/BrookfieldEnercare.SemanticModel/definition/tables/` |
| G3-2 | Build `nb_04_generate_tmdl.py` — reads `vw_business_metadata_current`, renders TMDL files | 🔴 Not Started | Sean | Core pipeline notebook |
| G3-3 | Add AI instructions injection from `ai_metadata` into TMDL model-level block | 🔴 Not Started | Sean | Requires G1-4 complete |
| G3-4 | Add verified answers injection from `ai_metadata` into TMDL | 🔴 Not Started | Sean | Requires G1-4 complete |
| G3-5 | Git commit + push step in nb_04 (via Fabric Files API or OneLake DFS write + manual sync) | 🔴 Not Started | Sean | Determine push mechanism |
| G3-6 | Test: run nb_04, verify TMDL diffs are correct, sync to Fabric, confirm descriptions appear in semantic model | 🔴 Not Started | Sean | |
| G3-7 | Document the approach for Christopher as the answer to the TOM/Windows VM question | 🟢 Done | Sean | Captured in meeting action items section of this doc |

---

## G4 — Copilot "Prep Data for AI"

**Priority:** P2 — direct path to Copilot accuracy and business adoption  
**Goal:** BrookfieldEnercare semantic model is fully configured for Copilot: large model storage, simplified schema, verified answers, AI instructions. Business users get trusted answers.  
**Status:** 🔴 Not Started — semantic model exists but AI configuration not applied  
**Dependency:** G3 (write-back pipeline) for automated delivery; G1-4 (`ai_metadata`) for content

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G4-1 | Enable large model storage on BrookfieldEnercare semantic model in Fabric settings | 🔴 Not Started | Sean | Fabric portal — Settings → Q&A |
| G4-2 | Review and simplify schema for Copilot: hide technical columns, set user-facing display names | 🔴 Not Started | Sean | |
| G4-3 | Draft initial AI instructions block for the semantic model (domain terminology, KPI mappings) | 🔴 Not Started | Sean + Christopher | Source from meeting discussion and `kpi_metadata` |
| G4-4 | Populate `ai_metadata` with verified Q&A pairs for top 10 high-frequency business questions | 🔴 Not Started | Sean + Ranbir | Business to provide questions; Sean to write verified answers |
| G4-5 | Deliver via G3 pipeline: AI instructions + verified answers → TMDL → Fabric sync | 🔴 Not Started | Sean | Depends on G3 complete |
| G4-6 | Test: ask Copilot the 10 verified questions; confirm answers match expected output | 🔴 Not Started | Sean + Christopher | Acceptance test |

---

## G5 — Standalone Copilot Governance

**Priority:** P2 — unblocks self-service at scale  
**Goal:** Standalone Copilot enabled in tenant, restricted to certified semantic models only. Business users can query across certified models without exposing all 300+ models.  
**Status:** ⏸ Blocked — pending Naunihal sharing tenant settings documentation with Christopher's team  
**Dependency:** IT admin access; Naunihal's follow-up from meeting

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G5-1 | Share Standalone Copilot tenant settings + enablement steps with Christopher's team | 🔴 Not Started | Naunihal | Meeting action item |
| G5-2 | Create "Certified Models" security group in Entra ID | 🔴 Not Started | Christopher / IT | |
| G5-3 | Add BrookfieldEnercare semantic model to approved list in tenant settings | 🔴 Not Started | Fabric admin | |
| G5-4 | Test: confirm Standalone Copilot surfaces only certified models for test users | 🔴 Not Started | Sean + Naunihal | |

---

## G6 — Purview Integration (Descriptions + Glossary + Sensitivity)

**Priority:** P2 — delivers discoverability; answer to "centralize metadata in OneLake catalog"  
**Goal:** Purview Unified Catalog populated with asset descriptions, column definitions, certified KPI glossary terms, and sensitivity labels — sourced automatically from `lh_metadata`.  
**Status:** 🔴 Not Started  
**Dependency:** G1 (metadata store complete), G2 (KPIs certified), Purview service principal

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G6-1 | Register Entra ID app registration for Purview API access; grant `Data Curator` role | 🔴 Not Started | Sean / IT | |
| G6-2 | Store client ID + secret in Fabric notebook environment variables or Key Vault | 🔴 Not Started | Sean | |
| G6-3 | Build `nb_05_purview_push.py` — reads `vw_business_metadata_current`, pushes to Atlas API | 🔴 Not Started | Sean | Adapt `06_purview_push_descriptions.py` from archive |
| G6-4 | Push asset and column descriptions to `mssql_column` qualified names (source assets) | 🔴 Not Started | Sean | |
| G6-5 | Push asset and column descriptions to `fabric_lakehouse_table_column` qualified names (OneLake) | 🔴 Not Started | Sean | New vs. original design |
| G6-6 | Push certified KPIs as Purview business glossary terms with owner assignment | 🔴 Not Started | Sean | Only `IsCertified = 1` rows |
| G6-7 | Push sensitivity labels from `sensitivity_classification` as MIP label mappings | 🔴 Not Started | Sean | |
| G6-8 | Test: verify assets appear in Purview with correct descriptions and glossary term assignments | 🔴 Not Started | Sean + Christopher | |

---

## G7 — Lineage Registration in Purview

**Priority:** P3 — impact analysis; depends on G6  
**Goal:** Three-hop column-level lineage in Purview: SQL view/source → OneLake Delta table → semantic model column → Power BI report visual. Impact analysis becomes possible when KPI logic changes.  
**Status:** 🔴 Not Started  
**Dependency:** G6 (Purview integration active), G1-7 (`lineage_edges` table)

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G7-1 | Populate `lineage_edges` table for all known transformation steps | 🔴 Not Started | Sean | Source → lh_enercare_demo → star schema → semantic model |
| G7-2 | Build `nb_06_purview_lineage.py` — registers Atlas Process entities per lineage edge | 🔴 Not Started | Sean | Adapt `07_purview_register_lineage.py` from archive |
| G7-3 | Register: SQL view → source table edge (view/proc as upstream node) | 🔴 Not Started | Sean | |
| G7-4 | Register: nb_03 notebook → star schema tables edge | 🔴 Not Started | Sean | |
| G7-5 | Register: star schema table → semantic model column edge (Direct Lake) | 🔴 Not Started | Sean | |
| G7-6 | Test: confirm lineage graph in Purview shows three hops for a sample column | 🔴 Not Started | Sean + Christopher | |

---

## G8 — AI Gap-Fill for Sparse Metadata

**Priority:** P2 — required to bootstrap; metadata sparsity directly degrades Copilot accuracy  
**Goal:** Undocumented assets and columns receive AI-drafted descriptions using Fabric-native AI functions. Drafts flagged `IsDraft = 1` for steward review before propagating.  
**Status:** 🔴 Not Started  
**Approach:** `ai_generate_text()` in Fabric Spark SQL — no external Azure OpenAI credentials needed

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G8-1 | Build `nb_07_ai_gap_fill.py` — queries `lh_metadata` for rows where `Description IS NULL`, calls `ai_generate_text()` | 🔴 Not Started | Sean | Fabric-native replacement for `ai_gap_fill.py` in archive |
| G8-2 | Write drafts with `IsDraft = 1` — do not propagate until approved | 🔴 Not Started | Sean | |
| G8-3 | Run against current `asset_metadata` and `column_metadata` — generate drafts for all demo assets | 🔴 Not Started | Sean | Validates approach before production |
| G8-4 | Review AI draft quality with Christopher/Ranbir — adjust prompt if needed | 🔴 Not Started | Sean + Christopher | |

---

## G9 — Steward Approval Workflow

**Priority:** P3 — required before metadata propagates to production Purview / semantic model  
**Goal:** Business owners can review and certify KPI definitions and AI-drafted descriptions. Only approved (`IsDraft = 0`, `IsCertified = 1`) rows propagate downstream.  
**Status:** 🔴 Not Started  
**Dependency:** G1 (metadata store), G2 (KPI certification fields), G8 (AI drafts to review)

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G9-1 | Build steward review notebook — shows `IsDraft = 1` rows filtered by domain owner | 🔴 Not Started | Sean | Phase 1: notebook-based; Phase 2: Power App |
| G9-2 | Add approval action: steward sets `IsDraft = 0` for approved rows | 🔴 Not Started | Sean | |
| G9-3 | Add KPI certification action: business owner sets `IsCertified = 1` with `CertifiedBy` | 🔴 Not Started | Sean | |
| G9-4 | Add drift alert: if `DefinitionHash` changes on an approved asset, reset `IsDraft = 1` and notify owner | 🔴 Not Started | Sean | |
| G9-5 | Agree on domain ownership matrix with Christopher/Ranbir — who approves what | 🔴 Not Started | Christopher / Ranbir | Business decision |

---

## G10 — Ontology Layer

**Priority:** P3 — longer-term; domain model requires business input  
**Goal:** Enercare-specific entity classes (Customer, ServiceAccount, Equipment, Contract, ServiceEvent, BillingEvent) registered as custom Purview types. Assets discoverable by domain, not just schema.  
**Status:** 🔴 Not Started  
**Dependency:** G6 (Purview integration), G1-8 (ontology tables in `lh_metadata`)

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G10-1 | Workshop with Christopher/Ranbir: define entity classes and relationships for Enercare domain | 🔴 Not Started | Sean + Christopher | Business input required |
| G10-2 | Populate `ontology_classes` and `ontology_relationships` tables from workshop output | 🔴 Not Started | Sean | |
| G10-3 | Register custom Atlas `EntityDef` types via Purview REST API | 🔴 Not Started | Sean | |
| G10-4 | Map existing `asset_metadata` rows to ontology classes (`OntologyClass` column) | 🔴 Not Started | Sean | |
| G10-5 | Update Purview push (G6) to use ontology `typeName` instead of generic `DataSet` | 🔴 Not Started | Sean | |

---

## G11 — B2C Customer Support Chatbot

**Priority:** P4 — blocked on IT/legal approval  
**Goal:** A chatbot combining structured data (Fabric / Power BI) with unstructured data (call transcripts) to answer customer support queries. Fabric Data Agent + AI Search + Copilot Studio.  
**Status:** ⏸ Blocked — IT/legal approval required for cross-region Fabric Data Agent data processing (Canada)  
**Dependency:** IT architecture review board approval

### Tasks

| # | Task | Status | Owner | Notes |
|---|---|---|---|---|
| G11-1 | Add Microsoft material to IT architecture review deck to support approval | 🔴 Not Started | Naunihal / Jonson | Meeting action item |
| G11-2 | Submit IT architecture review board request | 🔴 Not Started | Christopher / IT | |
| G11-3 | Design chatbot architecture: Data Agent + AI Search vector DB + Copilot Studio | 🔴 Not Started | Jonson / Naunihal | Can proceed in parallel with G11-1/2 |
| G11-4 | Investigate Azure AI Search vector DB integration with Standalone Copilot / Data Agent | 🔴 Not Started | Naunihal | Meeting action item |
| G11-5 | Schedule follow-up session focused on B2C/customer support use case | 🔴 Not Started | Jonson | Meeting action item |

---

## Meeting Action Items Tracker

| Action | Owner | Due | Status |
|---|---|---|---|
| Share Standalone Copilot tenant settings + enablement steps | Naunihal | ASAP | 🔴 Not Started |
| Add material to IT architecture review deck for Fabric Data Agent approval | Naunihal / Jonson | ASAP | 🔴 Not Started |
| Provide update on metadata storage alternatives + Purview lineage options | Brian / Sean | End of week (2026-05-08) | 🟡 In Progress — this document |
| Investigate Azure AI Search vector DB integration guidance | Naunihal | TBD | 🔴 Not Started |
| Schedule B2C chatbot follow-up session | Jonson | TBD | 🔴 Not Started |

---

## Technical Reference

### Metadata Store: `lh_metadata` (OneLake)
All consumers read from `vw_business_metadata_current`. Propagation targets:
- **Copilot / Data Agents** — grounded directly on `lh_metadata` tables
- **Semantic model** — via TMDL git pipeline (nb_04) — no TOM required
- **Purview** — via Atlas REST push (nb_05, nb_06)
- **Delta column comments** — via Spark SQL `ALTER TABLE ... COMMENT` (nb_02, already coded)

### Semantic Model Write-Back: Git TMDL Pipeline (Answer to TOM Question)
TMDL files in `/pbi/BrookfieldEnercare.SemanticModel/definition/tables/` are the live source of truth for the semantic model. `nb_04_generate_tmdl.py` renders updated TMDL from `lh_metadata`, commits to `enercare` branch, Fabric Source Control sync applies changes. No TOM, no Windows VM.

### Purview Qualified Name Patterns
| Asset Type | Pattern |
|---|---|
| Source SQL view | `mssql://<server>/<database>/<schema>/<object>` |
| OneLake Delta table | `fabric://<workspace-id>/<lakehouse>/<table>` |
| Semantic model column | `powerbi://api.powerbi.com/v1.0/myorg/<workspace>/<model>/<table>/<column>` |
| Power BI report visual | `powerbi://api.powerbi.com/v1.0/myorg/<workspace>/<report>/<page>/<visual>` |

### Key File Locations
| File | Purpose |
|---|---|
| `pbi/nb_02_metadata_pipeline_demo.Notebook/` | Metadata extractor + Purview dry-run (activate by setting `DEMO_MODE = False`) |
| `pbi/nb_03_pbi_star_schema.Notebook/` | Star schema builder |
| `pbi/BrookfieldEnercare.SemanticModel/definition/` | TMDL source files — target for nb_04 output |
| `pbi/Enercare Governance Agent.DataAgent/` | Data Agent config — AI instructions in `stage_config.json` |
| `archive/original/purview/` | Reference scripts: `06_purview_push_descriptions.py`, `07_purview_register_lineage.py`, `ai_gap_fill.py` |
