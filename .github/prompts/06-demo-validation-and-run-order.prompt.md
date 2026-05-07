---
mode: agent
description: "Final: update demo README, run-order script, and gap tracker to reflect completed build"
tools: ["filesystem"]
---

# Demo Validation, Run Order, and Final Cleanup

## Dependencies
All previous prompts (01–05) complete. Read current state of `docs/design-gap-analysis.md`
before making changes to ensure statuses reflect actual completion.

---

## Task 1 — Update demo/README.md

Extend the existing `demo/README.md` to include the full run order for all notebooks
(the original only covers nb_01 and nb_02). Append a new section:

```markdown
## Full Pipeline Run Order (Post-Build)

| Step | Notebook | What it does | Must run before |
|---|---|---|---|
| 1 | nb_01_setup_demo_environment | Creates all Delta tables in lh_enercare_demo | everything |
| 2 | nb_02_metadata_pipeline_demo | 5-phase metadata extract → lh_metadata (DEMO_MODE=True first) | nb_01 |
| 3 | nb_03_pbi_star_schema | Builds star schema tables | nb_01 |
| 4 | nb_04a_extend_metadata_schema | Extends lh_metadata schema, seeds KPIs + AI metadata | nb_02 |
| 5 | nb_04_generate_tmdl | Renders enriched TMDL → commits to repo | nb_04a |
| 6 | nb_04b_inject_ai_instructions | Injects AI instructions + verified answers into model.tmdl | nb_04a |
| 7 | nb_07_ai_gap_fill | AI-drafts missing descriptions (IsDraft=1) | nb_04a |
| 8 | nb_05_purview_push (purview/) | Registers assets, glossary, business metadata in Purview | nb_04a |
| 9 | nb_06_purview_lineage (purview/) | Registers lineage edges in Purview | nb_05 |

### After running all notebooks
1. Trigger Fabric Source Control sync in the workspace to apply TMDL changes
2. Open Power BI semantic model → confirm column descriptions appear
3. Open Purview → confirm assets, glossary terms, lineage are visible
4. Enable large model storage on BrookfieldEnercare semantic model (see docs/copilot-prep-checklist.md)
5. Run the demo scenario: see demo/README.md#demo-scenario-a

## Demo Scenario A — Standalone Copilot (10 minutes)

**Prerequisite**: All notebooks run. Standalone Copilot preview enabled in tenant.

### Step 1 — Show the before state (1 min)
Open Purview → search `ref_cc_billing_adj_category` → show ORPHANED classification,
no descriptions, no lineage. Say: "This is a real table pattern from Enercare's catalog."

### Step 2 — Run the pipeline (2 min)
Set DEMO_MODE=False on nb_04_generate_tmdl. Run. Sync Fabric Source Control.
Open Power BI semantic model → show that fcr_flag now reads:
"1 = resolved without customer callback within 5 business days. Feeds the FCR Rate measure."

### Step 3 — Ask Copilot (3 min)
In Power BI report chat pane, ask:
> "What is our PP renewal rate?"
→ Verified answer returns: 82% target, certified definition, steward name.

> "Break it down by customers who called the billing queue versus those who didn't."
→ Should surface: billing callers ~57%, non-billing ~76% (the 19pp gap).

> "What were billing queue customers calling about before their PP lapsed?"
→ Returns intent labels: billing_dispute 44%, invoice_inquiry 18% (from transcript turns).

### Step 4 — Close the loop (3 min)
Run nb_05_purview_push.py Cell 7 (write_insight_to_purview) with:
  - insight_text = "41% of PP non-renewals in Q1 followed billing calls about invoice confusion"
  - linked_kpi_codes = ["PP_RNW_RATE"]

Open Purview → ref_cc_billing_adj_category → show the AI annotation in business metadata.
Ask Copilot the same question again → response now includes the annotation.
Say: "The metadata is smarter than when we started — without any manual documentation."

### Step 5 — Closing (1 min)
"When the Data Agent cross-border approval lands, this same semantic model feeds an agent
assist in Teams — agents see customer history and last transcript before they answer.
Same enrichment work, second surface unlocked."
```

---

## Task 2 — Create scripts/run_demo.py

Write `demo/fabric/run_demo.py` — a presenter control script that wraps all notebooks
in the correct order with interactive pauses for demo narration.

```python
#!/usr/bin/env python3
"""
Enercare Demo Run Controller
Usage:
  python demo/fabric/run_demo.py --mode dry_run   # validate all notebooks exist
  python demo/fabric/run_demo.py --mode demo       # step-through with narration pauses
  python demo/fabric/run_demo.py --mode full       # run entire pipeline non-interactively

IMPORTANT: This script triggers Fabric notebooks via REST API.
All credentials loaded from environment variables (Key Vault at runtime).
See .env.example for required variables.
"""

import os, sys, time, requests
from azure.identity import DefaultAzureCredential

NOTEBOOKS = [
    ("nb_01_setup_demo_environment",  "Setting up demo data in lh_enercare_demo"),
    ("nb_02_metadata_pipeline_demo",  "Running 5-phase metadata extraction"),
    ("nb_03_pbi_star_schema",         "Building star schema"),
    ("nb_04a_extend_metadata_schema", "Extending lh_metadata schema + seeding KPIs"),
    ("nb_04_generate_tmdl",           "Writing descriptions to TMDL files"),
    ("nb_04b_inject_ai_instructions", "Injecting AI instructions + verified answers"),
    ("nb_07_ai_gap_fill",             "AI gap-fill for sparse metadata (IsDraft=1)"),
    ("nb_05_purview_push",            "Registering assets in Purview"),
    ("nb_06_purview_lineage",         "Registering lineage in Purview"),
]

DEMO_NARRATION = {
    "nb_04_generate_tmdl":    "PAUSE: After this runs, sync Fabric Source Control. Then open the semantic model to show descriptions are live.",
    "nb_05_purview_push":     "PAUSE: After this runs, open Purview to show assets, glossary terms, and the ORPHANED flag on ref_cc_billing_adj_category.",
    "nb_06_purview_lineage":  "PAUSE: Open Purview lineage view. Show the 2-hop graph: source system → OneLake → semantic model.",
}

def run(mode="dry_run"):
    # Implementation: iterate NOTEBOOKS, trigger each via Fabric REST API
    # Pause at DEMO_NARRATION steps if mode=="demo"
    # See context/api-endpoints.json run_notebook endpoint
    pass  # GHCP: implement this function

if __name__ == "__main__":
    mode = sys.argv[1].replace("--mode=", "").replace("--mode ", "") if len(sys.argv) > 1 else "dry_run"
    run(mode)
```

---

## Task 3 — Final gap tracker update

Update `docs/design-gap-analysis.md` Quick Status table to reflect the completed build.
Set the following statuses:

| Gap | New Status |
|---|---|
| G1 | 🟢 Done |
| G2 | 🟢 Done |
| G3 | 🟡 In Progress (code complete; Fabric Source Control sync + credential setup pending) |
| G4 | 🟡 In Progress (code complete; manual portal steps + tenant preview pending — see copilot-prep-checklist.md) |
| G5 | ⏸ Blocked (no change — pending Alison + IT) |
| G6 | 🟡 In Progress (code complete; Purview service principal setup pending) |
| G7 | 🟡 In Progress (code complete; depends on G6 credentials) |
| G8 | 🟢 Done |
| G9 | 🔴 Not Started (no change) |
| G10 | 🔴 Not Started (no change) |
| G11 | ⏸ Blocked (no change) |
| CC  | 🟢 Done |

Also update the "Meeting Action Items Tracker" at the bottom of the gap analysis:
- "Provide update on metadata storage alternatives + Purview lineage options" →
  Status: `🟢 Done` — Notes: "TMDL git pipeline approach documented in G3. nb_04_generate_tmdl.py delivered. No TOM, no Windows VM."
