# Enercare — Metadata Platform Product Gap Analysis

**Date:** 2026-05-05  
**Meeting participants:** Christopher Dingle (VP Data & Analytics), Ranbir Singh, Ci Zhu, Brian Lung, Sean Kelley, Naunihal Singh Sidhu, Jonson Tsai, Shaun Callighan  
**Purpose:** Map Enercare's stated metadata and governance goals to current platform state, identify gaps, and define a prioritized implementation plan using Microsoft Fabric and Microsoft Purview.

---

## 1. Customer Goals (Source: 2026-05-05 Meeting)

The following goals were explicitly stated or directly implied by Enercare stakeholders.

### G1 — Standardized Semantic Layer
Consolidate from hundreds of purpose-built Power BI models to a small number of reusable, certified semantic models. Target: approximately 150 users per shared model. KPI logic must be consistent, centrally defined, and consistently propagated across all consumer surfaces.

### G2 — Centralized KPI Governance
Business stakeholders — not the data analytics team — must own KPI definitions. This includes initial sign-off on logic, approval of changes, and control over which workgroups and vendors consume certified definitions. Change tracking is required.

### G3 — Copilot and AI Enablement
Business users should be able to ask questions of their data, generate insights, and build their own reports without depending on analysts. Copilot accuracy is directly dependent on the quality of metadata behind the semantic model: descriptions, naming standards, AI instructions, and verified answers. "Good metadata" is a prerequisite, not a follow-on.

### G4 — Metadata-Driven Discoverability
Developers, analysts, and end users must be able to find data assets and understand their meaning without relying on tribal knowledge. OneLake catalog (Purview Unified Catalog) is the preferred destination. Third-party catalog tools are not desired.

### G5 — Lineage and Impact Analysis
When a KPI definition or source table changes, the team needs to know what reports and models are affected. Column-level lineage from source system through to Power BI report is the target.

### G6 — Self-Service Analytics
Reduce the bottleneck on the central data analytics team. Business users should be able to create their own reports from certified models and query data directly through Copilot or Data Agents.

### G7 — Real-Time Operational Analytics
Move from daily dashboard refresh to near-real-time (15-minute intervals) for operational use cases, particularly the call center.

### G8 — B2C Customer Support Intelligence
A future chatbot that combines structured data (Power BI / Fabric) with unstructured data (call transcripts, case notes) to answer customer support queries. Blocked pending IT/legal approval for cross-region Fabric Data Agent processing.

---

## 2. Current State at Enercare

| Area | Current State |
|---|---|
| Power BI models | Hundreds of purpose-built models; KPI logic diverges across dashboards |
| KPI definitions | Not centrally stored; defined per-model; inconsistently propagated |
| Metadata | "Very, very naive" (Christopher); sparse; stored informally in views and stored procedures |
| Metadata repository | None — no structured, queryable catalog |
| Metadata writeback | SemPy can read semantic model metadata but cannot write; TOM/XMLA required for write-back; Windows VM dependency is impractical |
| Copilot for Power BI | Enabled; not yet configured with AI instructions, verified answers, or "prep data for AI" |
| Standalone Copilot | Not yet enabled; tenant settings not configured |
| Fabric Data Agent | Enabled in principle; blocked on IT/legal approval for cross-region data processing (Canada) |
| Purview | Available; not integrated with Power BI or Fabric metadata; no lineage registered |
| Mirroring | Mirroring does not transfer metadata — descriptions from source do not carry through |
| Documentation | Largely absent; onboarding depends on specific individuals |

---

## 3. Gap Analysis

Each gap maps a customer goal to what is currently missing.

---

### Gap 1 — No Canonical Metadata Store
**Goal:** G1, G2, G4  
**Current state:** Metadata exists informally in SQL views and stored procedures. There is no queryable, structured repository that other systems can read from.  
**Impact:** KPI definitions cannot be governed, versioned, or propagated. Copilot cannot be grounded on authoritative definitions. Purview cannot be populated automatically.  
**Required:** A Fabric Lakehouse (`lh_metadata`) with structured Delta tables for asset descriptions, column definitions, KPI definitions, data owners, sensitivity classifications, and AI instructions. All downstream systems read from this single hub.

---

### Gap 2 — No Certified KPI Definition Layer
**Goal:** G2, G1  
**Current state:** KPI logic is embedded per-model, inconsistent, and not subject to formal business approval.  
**Impact:** Business users receive different answers to the same question depending on which dashboard they open. Copilot cannot produce trusted KPI answers.  
**Required:** A `kpi_metadata` table in `lh_metadata` with KPI name, formula, business description, owner, steward, certification status, and version history. A lightweight approval workflow (IsCertified flag + owner sign-off) gates promotion to production. Certified KPIs propagate to the semantic model as named DAX measures with descriptions.

---

### Gap 3 — No Metadata Write-Back to Semantic Models
**Goal:** G1, G3  
**Current state:** SemPy (available in Fabric notebooks) is read-only. TOM/XMLA write-back requires Windows-based libraries — impractical in a Fabric-native environment.  
**Impact:** Descriptions, AI instructions, and verified answers cannot be automatically applied to the semantic model from the metadata store.  
**Required:** A git-based TMDL generation pipeline. Because the semantic model is maintained as TMDL source files in a git repository connected to the Fabric workspace, a Fabric notebook can render updated TMDL files from `lh_metadata`, commit them to git, and trigger a Fabric Source Control sync — achieving full write-back with no TOM dependency, no Windows VM, and no external tooling. This is the Fabric-native alternative Christopher asked about.

---

### Gap 4 — Copilot Not Configured for Business Use
**Goal:** G3, G6  
**Current state:** Copilot for Power BI is enabled at the tenant level but the semantic model has not been prepared for AI use: no AI instructions, no verified answers, no "prep data for AI" configuration, schema not simplified for Copilot consumption.  
**Impact:** Copilot produces generic or hallucinated answers. Business users do not trust it. The self-service goal cannot be achieved.  
**Required:** Four components of "prep data for AI" applied to the certified semantic model: (1) large model storage enabled, (2) schema simplified for Copilot, (3) verified answers added for known high-frequency questions, (4) AI instructions embedded to define business terms, KPI meanings, and response formatting. These are sourced from `lh_metadata` and applied via the TMDL pipeline (Gap 3).

---

### Gap 5 — Standalone Copilot Not Enabled or Governed
**Goal:** G3, G6  
**Current state:** Standalone Copilot (cross-model discovery) is not yet enabled. When enabled, it will expose all tenant models unless restricted.  
**Impact:** Business users cannot query across certified models. When enabled without governance, all 300+ models are exposed, undermining trust and accuracy.  
**Required:** Tenant admin settings to enable Standalone Copilot scoped to an approved-models security group containing only certified semantic models. Certified model list is maintained in `lh_metadata` (or as a Fabric data catalog tag).

---

### Gap 6 — No Purview Integration (Descriptions, Glossary, Sensitivity)
**Goal:** G4, G2  
**Current state:** Purview is available but has no connection to the Fabric metadata pipeline. Asset descriptions, column-level definitions, KPI glossary terms, and sensitivity labels are not registered.  
**Impact:** Purview search returns bare schema objects with no business context. Data catalog is not usable for discoverability. Governance reporting is absent.  
**Required:** An automated Purview push pipeline that reads `lh_metadata` and writes: (1) asset and column descriptions to qualified name assets in Purview, (2) KPI definitions as business glossary terms with owner assignment, (3) sensitivity labels from `sensitivity_classification` as MIP label mappings.

---

### Gap 7 — No Lineage Registered in Purview
**Goal:** G5  
**Current state:** Purview can scan Fabric and Azure SQL assets and infer table-level lineage from Mirroring. It does not automatically capture: view/stored-proc → table transformations, notebook-driven transformations, or semantic model → report dependencies.  
**Impact:** Impact analysis is impossible. When a KPI changes, there is no way to enumerate affected reports. Onboarding developers cannot trace a metric back to its source.  
**Required:** Custom Atlas Process entities registered via the Purview API for each transformation step: SQL view → source table, Fabric notebook → Delta table, Delta table → semantic model column, semantic model measure → Power BI report visual. This gives three-hop column-level lineage in Purview.

---

### Gap 8 — AI Gap-Fill Not Available
**Goal:** G4, G3  
**Current state:** Metadata is sparse. There is no automated mechanism to draft descriptions for objects that have none.  
**Impact:** Bootstrapping the catalog manually for hundreds of assets is impractical. Sparse metadata directly degrades Copilot accuracy.  
**Required:** A Fabric-native AI gap-fill notebook using `ai_generate_text()` (Fabric Spark SQL) to draft descriptions for undocumented assets and columns. Drafts are written with `IsDraft = 1` and require steward approval before propagating to Purview or the semantic model.

---

### Gap 9 — No Steward Approval Workflow
**Goal:** G2, G5  
**Current state:** No mechanism exists for business owners to review and certify KPI definitions, approve AI-generated descriptions, or sign off on metadata changes.  
**Impact:** Governance is aspirational. Without a certification gate, unchecked or incorrect metadata propagates to Copilot and Purview.  
**Required:** A lightweight approval surface — initially a Fabric notebook with a filtered view of `IsDraft = 1` rows for each steward. KPI certification requires the designated business owner (`kpi_metadata.Owner`) to promote `IsCertified` from 0 to 1. A Power App interface is the longer-term target.

---

### Gap 10 — No Ontology Layer
**Goal:** G4, G5  
**Current state:** Assets are registered in Purview as generic `DataSet` and `Column` types. There is no Enercare-specific entity model.  
**Impact:** Purview search and lineage does not reflect the business domain. Ontology-driven governance (e.g., "show me all assets related to the Customer domain") is not possible.  
**Required:** A domain ontology defining Enercare entity classes (Customer, ServiceAccount, Equipment, Contract, ServiceEvent, BillingEvent, Product) and their relationships, registered as custom Atlas `EntityDef` types in Purview. Star schema tables and semantic model measures are mapped to their ontology class, enabling domain-scoped discovery and lineage queries.

---

### Gap 11 — B2C Chatbot (Structured + Unstructured)
**Goal:** G8  
**Current state:** Capability exists in Fabric (Data Agent + AI Search + Copilot Studio) but is blocked on IT/legal approval for cross-region data processing.  
**Impact:** Customer support self-service is not possible until approved.  
**Required:** IT architecture review board approval for Fabric Data Agent cross-region processing. Technical implementation follows approval: configure Data Agent to access both structured (semantic model) and unstructured (AI Search over call transcripts) sources, integrate with Copilot Studio for M365 Copilot embedding.

---

## 4. Priority Order

| Priority | Gap | Rationale |
|---|---|---|
| 1 | Gap 1 — Canonical metadata store | Everything else depends on it |
| 2 | Gap 2 — Certified KPI definitions | Primary business driver stated in meeting |
| 3 | Gap 3 — Metadata write-back (TMDL pipeline) | Unblocks Copilot configuration and Purview descriptions |
| 4 | Gap 4 — Copilot "prep data for AI" | Direct path to Copilot accuracy and business adoption |
| 5 | Gap 8 — AI gap-fill | Required to bootstrap sparse metadata at scale |
| 6 | Gap 6 — Purview descriptions + glossary | Delivers discoverability; depends on Gap 1 |
| 7 | Gap 5 — Standalone Copilot governance | Admin task; unblocks self-service at scale |
| 8 | Gap 9 — Steward approval workflow | Required before production metadata propagates |
| 9 | Gap 7 — Purview lineage | Impact analysis; depends on Purview integration (Gap 6) |
| 10 | Gap 10 — Ontology | Longer-term; domain model to be defined with business |
| 11 | Gap 11 — B2C chatbot | Blocked on IT/legal; technical design can proceed in parallel |

---

## 5. Implementation Approach

The implementation uses the existing Fabric workspace (`lh_metadata`, `lh_enercare_demo`, semantic model, Data Agent) as the foundation and extends it across six phases.

### Phase 1 — Canonical Metadata Store (Gaps 1, 2)
Build or extend `lh_metadata` with the full schema:
- `asset_metadata` — asset descriptions, owner, steward, sensitivity, domain
- `column_metadata` — column descriptions, IsDraft flag
- `kpi_metadata` — formula, unit, owner, `IsCertified`, version, `PreviousFormula`
- `ai_metadata` — verified answers, AI instructions per model, term mappings
- `data_owners` — ownership registry by domain
- `sensitivity_classification` — sensitivity label mappings
- `lineage_edges` — transformation graph (source → target)
- `ontology_classes` / `ontology_relationships` — domain entity model
- `vw_business_metadata_current` — wide view, single read interface for all consumers

Populate from existing `@tag` headers in SQL views/stored procedures via the extraction notebook. Run AI gap-fill to bootstrap sparse assets (Gap 8, Phase 2).

### Phase 2 — AI Gap-Fill + Steward Workflow (Gaps 8, 9)
Deploy Fabric-native AI gap-fill using `ai_generate_text()`. Draft descriptions are written with `IsDraft = 1`. A steward review notebook surfaces pending approvals by domain owner. Certified rows (`IsDraft = 0`, `IsCertified = 1` for KPIs) are the only rows that propagate downstream.

### Phase 3 — Semantic Model Metadata Write-Back (Gap 3, 4)
Build `nb_04_generate_tmdl.py`. This notebook reads `vw_business_metadata_current` and `ai_metadata`, renders TMDL table files with descriptions and AI instructions, and commits them to the git repository. The Fabric workspace Source Control sync applies the changes to the live semantic model. No TOM, no Windows VM. This resolves the write-back constraint raised in the meeting.

Apply "prep data for AI" settings to the `BrookfieldEnercare` semantic model: large model storage, schema simplification, verified answers from `ai_metadata`, AI instructions from `ai_metadata`.

### Phase 4 — Purview Integration (Gaps 6, 5)
Build `nb_05_purview_push.py` to push from `lh_metadata` to Purview:
- Column and asset descriptions to qualified name assets
- KPI definitions as business glossary terms with certified owner assignment
- Sensitivity labels as MIP mappings

Enable and scope Standalone Copilot in tenant settings to the certified model security group.

### Phase 5 — Lineage Registration (Gap 7)
Build `nb_06_purview_lineage.py` to register custom Atlas Process entities for each transformation step: SQL view → source table, notebook → Delta table, Delta table → semantic model column, semantic model → report visual. Delivers three-hop column-level lineage.

### Phase 6 — Ontology + B2C (Gaps 10, 11)
Define Enercare domain entity classes with business stakeholders. Register as Atlas custom `EntityDef` types. Map existing catalog assets to ontology classes in the Purview push pipeline.

In parallel: support IT/legal approval process for cross-region Fabric Data Agent. Design B2C chatbot architecture (Data Agent + AI Search + Copilot Studio) once approval is secured.

---

## 6. Answer to Meeting Action Items

### "Provide an update on alternatives for storing and managing metadata in Fabric, including options for data lineage and integration with Purview." (Brian Lung / Sean Kelley — due end of week)

**Recommended approach:** `lh_metadata` in OneLake is the canonical store. Metadata is authored once — via structured `@tag` headers in SQL views or sidecar YAML files — extracted by a Fabric PySpark notebook, and stored in Delta tables. All consumers (Copilot, Data Agents, Purview, semantic model) read from `lh_metadata.vw_business_metadata_current`. This avoids mirroring metadata through SQL (mirroring does not transfer descriptions), avoids third-party tools, and keeps everything within the Fabric/Purview boundary.

For **data lineage**: custom Atlas Process entities registered via the Purview REST API (pyapacheatlas library) model each transformation step as a first-class lineage node. Fabric's native scan captures table-level lineage from Mirroring; the custom registration layer adds view/proc → table and semantic model → report edges that Fabric cannot infer automatically.

### "More friendly Fabric Python notebook alternatives to TOM for metadata write-back?" (Christopher Dingle)

**Answer:** The semantic model in this project is maintained as TMDL source files in a git repository connected to the Fabric workspace via Source Control. A Fabric PySpark notebook (`nb_04_generate_tmdl.py`) reads `lh_metadata`, renders updated TMDL files with descriptions, AI instructions, and verified answers, and commits them to the repository. The Fabric workspace Source Control sync applies the changes to the live model. This is fully Fabric-native, requires no TOM, no `pythonnet`, and no Windows VM. The only trade-off vs. direct TOM is propagation latency (seconds via git vs. milliseconds in-memory) — acceptable for a scheduled metadata pipeline.
