# sub2 SQL Source Mapping

This note defines the minimal Azure SQL source layer that should be created in `sub2` before Fabric mirroring is enabled.

## Scope

The current star schema notebook reads exactly seven transactional source tables from `lh_enercare_demo`.

| Source table | Produced by | Consumed by | Notes |
|---|---|---|---|
| `products` | `nb_01_setup_demo_environment.py` | `nb_02_pbi_star_schema.py` | Product master / rate-card source |
| `customers` | `nb_01_setup_demo_environment.py` | `nb_02_pbi_star_schema.py` | Customer master |
| `service_accounts` | `nb_01_setup_demo_environment.py` | `nb_02_pbi_star_schema.py` | Service/account grain bridge |
| `equipment_registry` | `nb_01_setup_demo_environment.py` | `nb_02_pbi_star_schema.py` | Installed equipment source |
| `contracts` | `nb_01_setup_demo_environment.py` | `nb_02_pbi_star_schema.py` | Contract / subscription source |
| `service_requests` | `nb_01_setup_demo_environment.py` | `nb_02_pbi_star_schema.py` | Service event source |
| `billing_transactions` | `nb_01_setup_demo_environment.py` | `nb_02_pbi_star_schema.py` | Billing fact source |

## Initial load order

Load the tables into Azure SQL in the following order to satisfy foreign-key dependencies:

1. `products`
2. `customers`
3. `service_accounts`
4. `equipment_registry`
5. `contracts`
6. `service_requests`
7. `billing_transactions`

## Initial expected row counts

These counts reflect the current synthetic dataset in `nb_01`.

| Table | Expected rows |
|---|---:|
| `products` | 10 |
| `customers` | 50 |
| `service_accounts` | 56 |
| `equipment_registry` | 38 |
| `contracts` | 56 |
| `service_requests` | 30 |
| `billing_transactions` | computed / variable; currently approximately 585 |

## Deliberate exclusions from the first SQL source cut

The following `nb_01` outputs are not required for the first mirrored transactional source because they are not consumed by the current star schema notebook:

- `cc_agents`
- `ref_cc_billing_adj_category`
- `fct_cc_interactions`
- `fct_cc_transcript_turns`

These can be added to a later SQL-source expansion once the core seven-table path is stable.

## Repo artifacts for this step

- SQL DDL: `sql/02_sub2_sql_source_schema.sql`
- Fabric source mirror: `demo/fabric/nb_05a_publish_synthetic_data_to_sql.py`
- Fabric Git sync notebook: `pbi/nb_05a_publish_synthetic_data_to_sql.Notebook/`
