# Demo — Enercare Metadata Pipeline

End-to-end demo of the governance pipeline described in the root `README.md`.
Runs entirely inside Microsoft Fabric without a live SQL Server connection.
All `# TODO:` markers show exactly where to swap in production credentials.

---

## What's in this folder

```
demo/
├── README.md                              ← you are here
├── sql/
│   ├── 00_demo_schema_and_headers.sql     ← full T-SQL schema + 4 views with header convention
│   └── 01_demo_seed_data.sql              ← INSERT statements for all demo tables (run on SQL Server)
└── fabric/
    ├── nb_01_setup_demo_environment.py    ← Fabric notebook: creates Delta tables from inline data
    └── nb_02_metadata_pipeline_demo.py    ← Fabric notebook: full 5-phase pipeline (main workflow)
```

---

## Demo data model

Modelled on an Ontario residential/commercial energy services company.

| Table | Rows | Description |
|---|---|---|
| `customers` | 50 | Residential (40), Commercial (5), MUR (5) — Ontario cities |
| `service_accounts` | 56 | Natural Gas, HVAC, Water Heater, Electricity |
| `products` | 10 | Enercare-style rate card (rentals, protection plans, smart home) |
| `contracts` | 68 | Active, Cancelled, Expired |
| `equipment_registry` | 38 | Water heaters, furnaces, AC, heat pumps, thermostats |
| `service_requests` | 31 | Completed, InProgress, Open backlog |
| `billing_transactions` | ~300 | Jan–Jun 2024 monthly charges + payments |

**Real-world references used:**
- Postal codes: Statistics Canada Ontario FSAs (M, L, K, N prefixes)
- Equipment makes: Rheem, Bradford White, A.O. Smith, Lennox, Carrier, York, Goodman, ecobee, Honeywell Home
- Gas distributors: Enbridge Gas (Central/East ON), Union Gas (SW ON)
- Electricity distributor: Hydro One, Toronto Hydro
- Product pricing: Enercare public rate card (approximated)

---

## Views with full header convention

All four analytical views in `00_demo_schema_and_headers.sql` carry the complete
structured header that the metadata extractor parses.  They cover all supported tag types:

| View | Domain | Tags used |
|---|---|---|
| `vw_customer_360` | Customer | `@asset_type` `@description` `@owner` `@steward` `@domain` `@grain` `@refresh` `@sensitivity` `@glossary` `@upstream` `@column` (×14) `@kpi` (×4) `@notes` |
| `vw_monthly_revenue` | Revenue | full set, `@kpi` ×3 |
| `vw_equipment_health` | Operations | full set, `@kpi` ×3 |
| `vw_service_backlog` | Operations | full set, `@kpi` ×2 |

---

## Prerequisites

1. A Microsoft Fabric workspace with:
   - Lakehouse **`lh_enercare_demo`** (create it in the Fabric portal)
   - Lakehouse **`lh_metadata`** (create it; same workspace is fine)
2. Both lakehouses attached to the notebooks (see step 3 below)

> No SQL Server connection is required for the demo.  The notebooks generate
> all data in-memory from inline Python lists.

---

## Run order

### Step 1 — Set up lakehouses in Fabric

In the Fabric portal:
1. New → Lakehouse → name it `lh_enercare_demo` → Create
2. New → Lakehouse → name it `lh_metadata` → Create

### Step 2 — Create and configure notebook 1

1. New → Notebook → rename to `nb_01_setup_demo_environment`
2. **Add lakehouses**: Explorer pane → Add lakehouse → add both `lh_enercare_demo` and `lh_metadata`
3. Set `lh_enercare_demo` as the **default** lakehouse
4. Paste the contents of `demo/fabric/nb_01_setup_demo_environment.py` into the notebook
   (copy each `# CELL n` section into a separate notebook cell)
5. Run all cells

Expected output:
```
  customers:          50 rows written
  service_accounts:   56 rows written
  products:           10 rows written
  equipment_registry: 38 rows written
```

### Step 3 — Create and configure notebook 2

1. New → Notebook → rename to `nb_02_metadata_pipeline_demo`
2. Add the same two lakehouses; set `lh_enercare_demo` as default
3. Paste `demo/fabric/nb_02_metadata_pipeline_demo.py` into the notebook
4. Run all cells

Expected output (summary cell):
```
assets_extracted  columns_extracted  kpis_extracted
4                 51                 12
```
followed by dry-run previews of Delta column comments and Purview Atlas payloads.

---

## Swapping in production SQL Server data

All swap points are marked `# TODO:` in `nb_02_metadata_pipeline_demo.py`.

| Cell | What to change |
|---|---|
| **Cell 1** | Uncomment `SQL_JDBC_URL`, `SQL_USER`, `SQL_PASSWORD`; set `DEMO_MODE = False` |
| **Cell 2** | Replace `SQL_MODULES` dict with JDBC read from `sys.sql_modules` (template in the comment) |
| **Cell 1** | Uncomment `PURVIEW_ACCOUNT`, `PURVIEW_TENANT_ID`, `PURVIEW_CLIENT_ID`, `PURVIEW_SECRET` |
| **Cell 9** | Uncomment the `pyapacheatlas` push block |

The extractor logic (Cell 3), metadata writer (Cell 4), and Purview payload builder (Cell 9)
require **zero changes** when you swap the data source — only the ingestion step changes.

---

## Mapping to README.md phases

| README Phase | Demo file / cell |
|---|---|
| Phase 0 — Header convention | `00_demo_schema_and_headers.sql` views; `SQL_MODULES` dict in Cell 2 |
| Phase 1 — Extract to meta.* | nb_02 Cells 3–4 |
| Phase 2 — Replicate to OneLake hub | nb_02 Cell 5 (view creation; Delta tables already in Fabric) |
| Phase 3 — Land data via Mirroring | nb_01 (data loaded directly; replace with Mirroring in production) |
| Phase 4 — Apply to Fabric surfaces | nb_02 Cells 7–8 |
| Phase 5 — Govern with Purview | nb_02 Cell 9 |

---

## Running on SQL Server (optional)

If you have access to an Azure SQL DB / SQL Server instance you can also run the
SQL files to validate the schema and seed data before wiring up Mirroring:

```sql
-- 1. Create schema, tables, and views
--    (run against your test database)
:r demo/sql/00_demo_schema_and_headers.sql

-- 2. Insert sample data
:r demo/sql/01_demo_seed_data.sql

-- 3. Run the T-SQL metadata extractor
--    (already exists in the repo)
:r sql/02_extract_from_modules.sql
```

The T-SQL extractor in `sql/02_extract_from_modules.sql` will parse the header
comments in `00_demo_schema_and_headers.sql` and populate `meta.*` tables —
exactly the same metadata that the Python extractor in nb_02 Cell 3 produces.
