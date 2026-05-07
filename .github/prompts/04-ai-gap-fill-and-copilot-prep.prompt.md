---
mode: agent
description: "G4 + G8: AI gap-fill for sparse metadata, then Copilot prep data for AI"
tools: ["filesystem"]
---

# G4 + G8 — AI Gap-Fill and Copilot "Prep Data for AI" Configuration

## Dependencies
Run after prompts 01 and 03 are complete:
- `lh_metadata.ai_metadata` table exists (from prompt 01)
- `lh_metadata.kpi_metadata` is seeded with certified KPIs
- `nb_04_generate_tmdl.py` exists (from prompt 03)

---

## Task 1 — nb_07_ai_gap_fill.py (G8)

Write `demo/fabric/nb_07_ai_gap_fill.py` as a Fabric notebook cell-by-cell source file.

### What it does
Uses `ai_generate_text()` (Fabric-native Spark SQL function — no external Azure OpenAI
credentials needed) to generate description drafts for assets and columns where
`Description IS NULL` in `lh_metadata`. Drafts are written with `IsDraft = 1` so
they queue for steward review before propagating.

### Cell structure

**Cell 1 — Config**
```python
DEMO_MODE = True
METADATA_LAKEHOUSE = "lh_metadata"
MIN_NAME_LENGTH = 3  # skip columns with very short names (e.g. 'id', 'sk')
BATCH_SIZE = 50      # process N NULL descriptions per run to avoid timeout
```

**Cell 2 — Identify gaps**
```python
df_asset_gaps = spark.sql("""
    SELECT AssetName, AssetType, Domain
    FROM lh_metadata.asset_metadata
    WHERE Description IS NULL OR Description = ''
""")

df_column_gaps = spark.sql("""
    SELECT a.AssetName, c.ColumnName, a.Domain, a.AssetType
    FROM lh_metadata.column_metadata c
    JOIN lh_metadata.asset_metadata a ON a.AssetName = c.AssetName
    WHERE (c.Description IS NULL OR c.Description = '')
      AND LENGTH(c.ColumnName) >= {MIN_NAME_LENGTH}
    LIMIT {BATCH_SIZE}
""")

print(f"Asset gaps:  {df_asset_gaps.count()}")
print(f"Column gaps: {df_column_gaps.count()} (showing first {BATCH_SIZE})")
```

**Cell 3 — Generate drafts with ai_generate_text()**
```python
# Fabric-native AI text generation — no external credentials required
# Prompt is crafted to produce concise, business-oriented descriptions

df_column_gaps.createOrReplaceTempView("column_gaps")

df_drafted = spark.sql("""
    SELECT
        AssetName,
        ColumnName,
        ai_generate_text(
            CONCAT(
                'Write a one-sentence business description for a database column. ',
                'Table: ', AssetName, '. ',
                'Column: ', ColumnName, '. ',
                'Business domain: Enercare home services (HVAC, water heaters, Protection Plans). ',
                'Be specific and concise. Do not start with "This column".'
            )
        ) AS GeneratedDescription,
        current_date() AS DraftDate
    FROM column_gaps
""")

if DEMO_MODE:
    print("Sample AI-generated drafts:")
    df_drafted.show(10, truncate=80)
else:
    # Write drafts back to column_metadata with IsDraft = 1
    df_drafted.createOrReplaceTempView("drafted_descriptions")
    spark.sql("""
        MERGE INTO lh_metadata.column_metadata AS target
        USING drafted_descriptions AS source
        ON target.AssetName = source.AssetName AND target.ColumnName = source.ColumnName
        WHEN MATCHED AND (target.Description IS NULL OR target.Description = '')
            THEN UPDATE SET
                target.Description = source.GeneratedDescription,
                target.IsDraft = 1,
                target.ExtractedDate = source.DraftDate
    """)
    print(f"Wrote {df_drafted.count()} draft descriptions (IsDraft=1)")
    print("Next step: steward reviews via G9 workflow before propagating to semantic model")
```

**Cell 4 — Summary**
```python
df_remaining = spark.sql("""
    SELECT COUNT(*) as gaps_remaining
    FROM lh_metadata.column_metadata
    WHERE Description IS NULL OR Description = ''
""")
df_draft_count = spark.sql("SELECT COUNT(*) FROM lh_metadata.column_metadata WHERE IsDraft = 1")
print(f"IsDraft=1 (pending review): {df_draft_count.collect()[0][0]}")
print(f"Still NULL:                  {df_remaining.collect()[0][0]}")
```

---

## Task 2 — nb_04b_inject_ai_instructions.py (G4 extension)

Extend the TMDL write-back to inject AI instructions and verified answers from `ai_metadata`
into the semantic model. Write as a new file `demo/fabric/nb_04b_inject_ai_instructions.py`.

### What it writes into the TMDL
The `model.tmdl` file supports a `linguisticMetadata` and a `qaSetup` block.
Read `lh_metadata.ai_metadata` where `IsDraft = 0` and inject:

1. **AI Instructions block** (`RecordType = 'ai_instruction'`) into `model.tmdl`:
```tmdl
model BrookfieldEnercare
    ...existing content...
    qaSetup
        preparedInsights = true
        aiInstructions = """
{concatenated ResponseText from all ai_instruction rows, separated by newlines}
"""
```

2. **Verified answers** (`RecordType = 'verified_answer'`) into `model.tmdl`:
```tmdl
        verifiedAnswers
            verifiedAnswer
                question = "{TriggerText}"
                answer = "{ResponseText}"
```
One `verifiedAnswer` block per row where `IsDraft = 0` and `RecordType = 'verified_answer'`.

### DEMO_MODE behavior
- `True`: Print the full block that would be injected; show which trigger questions are covered
- `False`: Read `model.tmdl`, inject the block, write file, commit via git

### Cell structure
Reuse the `run()` git helper pattern from nb_04. After injection, print:
```
AI instructions injected: {n} instruction blocks
Verified answers injected: {n} Q&A pairs
Measures with verified answers: FCR Rate, Avg CSAT, PP Renewal Rate
Commit: {commit_hash or 'DEMO_MODE — not committed'}
```

---

## Task 3 — Copilot model settings checklist (G4-1 to G4-3)

Write a markdown file `docs/copilot-prep-checklist.md` with the exact Fabric portal steps
needed to complete G4 — things that require UI (can't be scripted):

```markdown
# Copilot "Prep Data for AI" — Manual Steps

## Prerequisites
- [ ] nb_04_generate_tmdl.py has run (DEMO_MODE=False) and Fabric Source Control synced
- [ ] nb_04b_inject_ai_instructions.py has run (DEMO_MODE=False) and synced
- [ ] lh_metadata.ai_metadata has IsDraft=0 rows for all 3 certified KPIs

## G4-1: Enable Large Model Storage
1. Fabric portal → Workspace → BrookfieldEnercare semantic model → Settings
2. Power BI → Large model storage format → ON
3. Wait for confirmation (may take a few minutes on first enable)

## G4-2: Simplified Schema for Copilot
1. Open the semantic model in Power BI Desktop (connected to Fabric workspace)
2. Hide columns that are technical-only: all *Key columns, lineage columns
3. Set user-facing synonyms on key columns (Fabric will use these for NLQ)
4. Publish back to Fabric workspace

## G4-3: Verify AI Instructions Appear
1. Open semantic model → Settings → Q&A setup
2. Confirm AI instructions text is populated (from nb_04b output)
3. Confirm verified answers list shows FCR, CSAT, PP Renewal Rate questions

## G4-6: Acceptance Test
Ask Copilot these questions and verify responses match verified_answer templates:
- "What is our FCR rate?"                    → should cite 78% target, certified definition
- "What is our PP renewal rate?"             → should cite 82% target
- "What is our average CSAT?"                → should note 22% response rate caveat
- "Why is PP renewal declining in billing?"  → should surface the 57% vs 76% correlation
```

---

After creating all files, update `docs/design-gap-analysis.md`:
- G8-1, G8-2, G8-3: `🟢 Done`
- G4-3, G4-4, G4-5: `🟢 Done`
- G4-1, G4-2, G4-6: `🟡 In Progress` (manual steps required — checklist created)
