---
mode: agent
description: "Additive: Add call center tables to nb_01 and extend nb_03 star schema + TMDL"
tools: ["filesystem"]
---

# Add Call Center Data Layer

## Context
The existing data model (customers, service_accounts, products, equipment, service_requests, billing)
is complete in `nb_01`. This prompt adds the call center layer on top — it does NOT modify
existing tables. Read `#file:context/enercare-schemas.json` section `section_b_call_center_extension`
and `#file:context/data-gen-config.json` for all table schemas and data distributions.

---

## Task 1 — Extend nb_01: add call center tables

Append new cells to `demo/fabric/nb_01_setup_demo_environment.py`. Do not touch existing cells.
Add a `# CELL ** — CALL CENTER EXTENSION` comment block before the new cells.

### Tables to create (inline PySpark, no SQL Server needed):

**`cc_agents`** (15 rows) — realistic Canadian names, team distribution from data-gen-config.json

**`ref_cc_billing_adj_category`** (12 rows) — include a comment:
```python
# DEMO NOTE: This table mirrors dbo.ref_cc_billing_adjustment_category_new
# in Enercare's actual Azure SQL estate — currently ORPHANED there (no mappings,
# no descriptions). We recreate it here to demonstrate the governance gap.
```
Seed codes: `LATE_FEE_WAIVER`, `DOUBLE_CHARGE_CREDIT`, `PLAN_PRICE_ADJ`,
`SERVICE_CREDIT`, `TAX_CORRECTION`, `PAYMENT_REVERSAL`, `GOODWILL_CREDIT`,
`BILLING_ERROR_ADJ`, `CONTRACT_DISPUTE_CR`, `DIRECT_DEBIT_FAIL`, `PROMO_ADJ`, `OTHER`

**`fct_cc_interactions`** (300 rows) — use distributions from data-gen-config.json:
- queue_type: billing 31%, pp_renewal 24%, hvac_service 18%, emergency 9%, new_pp_sales 11%, ecobee_support 4%, general 3%
- interaction_date: random across Oct 2025 – Mar 2026
- fcr_flag: per-queue rates from data-gen-config.json `fcr_rate_by_queue`
- csat_score: 22% NULL rate; non-NULL uses `csat_score.by_outcome` distributions
- **Demo correlation (critical)**: For pp_renewal queue in Jan–Mar 2026 (Q1), where
  customer_id matches a customer with a billing queue call in the prior 30 days,
  set pp_renewal_outcome = 'declined' at a 43% rate (vs 22% baseline).
  This is the 19pp gap Copilot surfaces.
- Join to existing `customers` table on customer_id

**`fct_cc_transcript_turns`** (~3,600 rows, avg 12 turns per interaction):
- Use phrase libraries from `#file:context/data-gen-config.json` section `transcripts.phrases_by_queue`
- Alternate speaker: customer/agent/customer/agent...
- For billing queue calls where pp_renewal_outcome = 'declined': ensure ≥1 turn with
  utterance_text containing "invoice" OR "charged twice" OR "billing confusion" —
  this is the text AI Search surfaces as the key insight

Print summary on completion:
```
Call center tables written:
  cc_agents:                  15 rows
  ref_cc_billing_adj_category: 12 rows  [ORPHANED demo asset]
  fct_cc_interactions:        300 rows
  fct_cc_transcript_turns:  ~3,600 rows
Demo correlation check: PP renewal rate (billing callers Q1): {rate:.1%}  [target: ~57%]
```

---

## Task 2 — Extend nb_03: add CC tables to star schema

Append to `pbi/nb_03_pbi_star_schema.Notebook/notebook-content.py` (or the demo/fabric source
equivalent). Add three new star schema tables from the call center Delta tables:

- `fct_cc_interactions` — already a fact; expose as-is with DateKey added
  (`interaction_date_key = YYYYMMDD INT` derived from `interaction_date`)
- `dim_cc_agent` — select from `cc_agents`
- `dim_cc_billing_adj` — select from `ref_cc_billing_adj_category`

---

## Task 3 — Create TMDL files for new CC tables

Create three new `.tmdl` files in `pbi/BrookfieldEnercare.SemanticModel/definition/tables/`:

### `fct_cc_interactions.tmdl`
- `mode: directLake`, `entityName: fct_cc_interactions`, `expressionSource: 'DirectLake - lh_enercare_demo'`
- Include all columns from the schema in `enercare-schemas.json`
- Add `description` on key columns:
  - `fcr_flag`: "1 = resolved without customer callback within 5 business days. Feeds the FCR Rate measure."
  - `csat_score`: "Post-call IVR satisfaction score 1.0–5.0. NULL = customer did not respond (~78% NULL rate)."
  - `pp_renewal_outcome`: "Result of any Protection Plan renewal discussion during this call."
  - `billing_adj_category`: "Billing adjustment applied, if any. Links to ref_cc_billing_adj_category."

### `dim_cc_agent.tmdl`
- DirectLake on `cc_agents`

### `dim_cc_billing_adj.tmdl`
- DirectLake on `ref_cc_billing_adj_category`
- Add `description` on the table: "Billing adjustment category reference. NOTE: mirrors dbo.ref_cc_billing_adjustment_category_new in Enercare prod — currently orphaned (no lineage, no descriptions). This demo shows what governance looks like after the metadata pipeline runs."

### Extend `_Measures.tmdl` — add 5 call center DAX measures

Append to the existing `_Measures.tmdl` file (do not overwrite — the 12 existing measures must remain):

```tmdl
    measure 'FCR Rate' = DIVIDE(CALCULATE(COUNTROWS(fct_cc_interactions), fct_cc_interactions[fcr_flag] = 1), COUNTROWS(fct_cc_interactions))
        description = "First Contact Resolution: % of interactions resolved without callback in 5 business days. Target: 78%."
        formatString: 0.0%

    measure 'Avg CSAT' = AVERAGEX(FILTER(fct_cc_interactions, NOT ISBLANK(fct_cc_interactions[csat_score])), fct_cc_interactions[csat_score])
        description = "Average post-call IVR satisfaction score (1–5). Excludes NULL responses (~78% non-response rate). Target: 4.2."
        formatString: #,0.0

    measure 'PP Renewal Rate' = DIVIDE(CALCULATE(COUNTROWS(fct_cc_interactions), fct_cc_interactions[pp_renewal_outcome] = "accepted"), CALCULATE(COUNTROWS(fct_cc_interactions), fct_cc_interactions[queue_type] = "pp_renewal"))
        description = "Protection Plan renewal acceptance rate on renewal queue calls. Target: 82%."
        formatString: 0.0%

    measure 'Avg Handle Time (sec)' = AVERAGE(fct_cc_interactions[handle_time_sec] + fct_cc_interactions[hold_time_sec])
        description = "Average total handle time in seconds (talk + hold). Billing queue target: 420s."
        formatString: #,0

    measure 'Escalation Rate' = DIVIDE(CALCULATE(COUNTROWS(fct_cc_interactions), fct_cc_interactions[escalated_flag] = 1), COUNTROWS(fct_cc_interactions))
        description = "Percentage of interactions escalated to supervisor or specialist queue."
        formatString: 0.0%
```

### Extend `relationships.tmdl` — add CC relationships

Append three relationships:
```tmdl
relationship fct_cc_interactions_interaction_date_key_dim_date_DateKey
    fromColumn: fct_cc_interactions.interaction_date_key
    toColumn: dim_date.DateKey

relationship fct_cc_interactions_agent_id_dim_cc_agent_agent_id
    fromColumn: fct_cc_interactions.agent_id
    toColumn: dim_cc_agent.agent_id

relationship fct_cc_interactions_customer_id_dim_customer_customer_id
    fromColumn: fct_cc_interactions.customer_id
    toColumn: dim_customer.customer_id
```

---

After completing all tasks, update `docs/design-gap-analysis.md` quick status table:
add a new row `| CC | Call center data layer | P1 | 🟢 Done | Sean |`
