# GitHub Copilot Setup — Enercare Fabric Solution

## What This Package Does

Adds GitHub Copilot context and structured prompts to the existing
**`RangerXP/BrookfieldEnercare-Fabric-Solution`** repo so GHCP can complete
the remaining build gaps (G1–G8) without needing to explain the project from scratch each time.

**This is an additive package — it does not replace anything already built.**

---

## Step 1 — Add to Your Repo

```bash
# From the repo root
cd "C:\Users\seankelley\OneDrive - Microsoft\Documents\Brookfield\Enercare\BrookfieldEnercare-Fabric-Solution"

# Copy the package contents in (adjust source path as needed)
cp -r /path/to/ghcp-handover/.github .
cp -r /path/to/ghcp-handover/context .
cp -r /path/to/ghcp-handover/.vscode .
cp /path/to/ghcp-handover/COPILOT-SETUP.md .

# The context/ and .github/ folders are new — safe to add without overwriting anything
git add .github/ context/ .vscode/ COPILOT-SETUP.md
git commit -m "chore: add GHCP context, prompts, and schema definitions"
git push origin enercare
```

After pushing, GHCP automatically loads `.github/copilot-instructions.md` in every chat session.

---

## Step 2 — Configure VS Code MCP

The `.vscode/mcp.json` is already set up. To activate:

1. Install the **GitHub Copilot** and **GitHub Copilot Chat** extensions in VS Code
2. Open the command palette (`Ctrl+Shift+P`) → `MCP: List Servers` — confirm `filesystem` appears
3. Sign in to GitHub Copilot if prompted

---

## Step 3 — Set GitHub Repo Variables (Actions → Variables, not Secrets)

```
AZURE_CLIENT_ID        = <service principal app ID>
AZURE_TENANT_ID        = <Azure tenant ID>
AZURE_SUBSCRIPTION_ID  = <subscription ID>
AZURE_RG_NAME          = <resource group>
KEYVAULT_NAME          = <key vault name>
FABRIC_WORKSPACE_ID    = <Fabric workspace GUID>
FABRIC_LAKEHOUSE_ID    = <lh_enercare_demo item GUID>
```

These are **not secrets** — they're public repo variables used by GitHub Actions OIDC.
The actual credentials (Purview service principal, git PAT) live in Key Vault only.

---

## Step 4 — Run GHCP Prompts in Order

Open VS Code Copilot Chat (`Ctrl+Shift+I`). Each prompt builds on the last.

### The 1-Day Sprint

| Order | Prompt | What GHCP builds | Est. time |
|---|---|---|---|
| 1 | `#file:.github/prompts/01-extend-lh-metadata-schema.prompt.md` | Extends `kpi_metadata`, creates `ai_metadata` + `data_owners` + `lineage_edges`, seeds 17 KPIs + verified answers → `nb_04a_extend_metadata_schema.py` | 30 min |
| 2 | `#file:.github/prompts/02-call-center-data-layer.prompt.md` | Adds CC tables to `nb_01`, extends `nb_03`, creates 3 TMDL files, extends `_Measures.tmdl` + `relationships.tmdl` | 45 min |
| 3 | Upload + run `nb_01` and `nb_03` in Fabric | All Delta tables live, star schema built | 20 min |
| 4 | `#file:.github/prompts/03-tmdl-writeback-notebook.prompt.md` | Builds `nb_04_generate_tmdl.py` — the core TMDL write-back pipeline | 40 min |
| 5 | Run `nb_02` (DEMO_MODE=False) then `nb_04a` then `nb_04` | `lh_metadata` enriched, TMDL descriptions injected, commit to branch | 25 min |
| 6 | Fabric Source Control sync | Descriptions live in semantic model | 5 min |
| 7 | `#file:.github/prompts/04-ai-gap-fill-and-copilot-prep.prompt.md` | Builds `nb_07_ai_gap_fill.py`, `nb_04b_inject_ai_instructions.py`, `copilot-prep-checklist.md` | 35 min |
| 8 | `#file:.github/prompts/05-purview-notebooks.prompt.md` | Builds `nb_05_purview_push.py` + `nb_06_purview_lineage.py` adapted from archive | 40 min |
| 9 | `#file:.github/prompts/06-demo-validation-and-run-order.prompt.md` | Updates `demo/README.md`, creates `run_demo.py`, finalises gap tracker | 20 min |
| 10 | Run Purview notebooks + validate loop | Assets in Purview, loop-close annotation live | 30 min |

**Total active work with GHCP: ~5 hours. Full 1-day sprint is realistic.**

---

## How to Invoke a Prompt

**Option A — File reference (recommended):**
In GHCP Chat, type:
```
#file:.github/prompts/01-extend-lh-metadata-schema.prompt.md
```
GHCP reads the prompt and all `#file:` references within it automatically.

**Option B — Slash command:**
The prompts appear as slash commands in GHCP Chat:
`/extend-lh-metadata-schema`, `/call-center-data-layer`, etc.

**Option C — Direct paste:**
Open the `.prompt.md` file, copy the content below the `---` frontmatter, paste into GHCP Chat.

---

## What's Already Done vs What GHCP Builds

| Component | Status | GHCP prompt |
|---|---|---|
| nb_01 (data setup) | ✅ Complete | Prompt 02 extends it |
| nb_02 (metadata pipeline) | ✅ Complete | No changes needed |
| nb_03 (star schema) | ✅ Complete | Prompt 02 extends it |
| Semantic model TMDL (9 tables) | ✅ Complete | Prompts 02+03 add to it |
| Data Agent config | ✅ Complete | Not touched |
| lh_metadata (3 tables) | ✅ Partial | Prompt 01 extends schema |
| kpi_metadata seeded | ❌ Empty | Prompt 01 |
| ai_metadata table | ❌ Missing | Prompt 01 |
| Call center tables | ❌ Missing | Prompt 02 |
| CC TMDL files | ❌ Missing | Prompt 02 |
| **nb_04_generate_tmdl** | ❌ **Missing** | **Prompt 03 (core gap)** |
| nb_04b AI instructions | ❌ Missing | Prompt 04 |
| nb_07 AI gap-fill | ❌ Missing | Prompt 04 |
| nb_05 Purview push | ❌ Missing | Prompt 05 |
| nb_06 Purview lineage | ❌ Missing | Prompt 05 |
| run_demo.py | ❌ Missing | Prompt 06 |

---

## Context Files Reference

| File | Used by prompts |
|---|---|
| `context/kpi-definitions.json` | 01, 02, 03, 04, 06 |
| `context/enercare-schemas.json` | 01, 02, 03, 05 |
| `context/data-gen-config.json` | 02 |
| `context/purview-type-defs.json` | 05 |
| `context/api-endpoints.json` | 03, 05 |

---

## Blockers That Are NOT in This Build

These require actions outside the repo — they block demo surface completion but not code:

| Blocker | Owner | What unblocks it |
|---|---|---|
| Standalone Copilot preview not confirmed enabled in Enercare tenant | Alison Pouw → Christopher's IT | Tenant settings doc + IT enablement |
| Purview service principal (G6-1, G6-2) | Alison Pouw | Entra app registration + Data Curator role |
| Fabric Data Agent cross-border approval | Brian Lung / PG | EARB 2026-5-21 response |
| Git PAT for TMDL commit push | Sean | Personal Access Token → Key Vault |

---

*Package version 2.0 — updated after local repo inventory 2026-05-06*
*Repo: https://github.com/RangerXP/BrookfieldEnercare-Fabric-Solution*
