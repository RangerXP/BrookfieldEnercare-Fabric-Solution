# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "0ee837e4-2fd3-40d9-b228-1f167b504b7d",
# META       "default_lakehouse_name": "lh_enercare_demo",
# META       "default_lakehouse_workspace_id": "795ce5db-7ea0-4a7c-ba64-e27c9fb568f4"
# META     },
# META     "warehouse": {
# META       "default_warehouse": "595a4488-0f92-41b6-9cdb-f7e09337c2de",
# META       "known_warehouses": [
# META         {
# META           "id": "595a4488-0f92-41b6-9cdb-f7e09337c2de",
# META           "type": "Lakewarehouse"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# =============================================================================
# nb_03_pbi_star_schema.py
# Fabric Notebook — Cell-by-cell (paste into a Spark notebook in Fabric)
#
# Purpose : Builds a Power BI-ready star schema on top of lh_enercare_demo.
#           Reads from the 7 source tables written by nb_01 and writes
#           dimension and fact tables back to the same lakehouse.
#
# Run after : nb_01_setup_demo_environment.py
# Prereqs   : Attach this notebook to lh_enercare_demo (default lakehouse)
# =============================================================================


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

DEMO_LAKEHOUSE = "lh_enercare_demo"

print(f"Source / target lakehouse : {DEMO_LAKEHOUSE}")
print(f"SparkSession              : {spark.version}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import pandas as pd
from pyspark.sql.types import *

# Build dim_date in Python, then create/replace the Delta table from a temp view
# ---------------------------------------------------------------------------
date_schema = StructType([
    StructField("DateKey",      IntegerType(), False),
    StructField("FullDate",     DateType(),    False),
    StructField("Year",         IntegerType(), False),
    StructField("Quarter",      IntegerType(), False),
    StructField("Month",        IntegerType(), False),
    StructField("MonthName",    StringType(),  False),
    StructField("Day",          IntegerType(), False),
    StructField("WeekOfYear",   IntegerType(), False),
    StructField("DayOfWeek",    IntegerType(), False),
    StructField("DayName",      StringType(),  False),
    StructField("IsWeekend",    IntegerType(), False),
    StructField("IsLeapYear",   IntegerType(), False),
    StructField("FiscalYear",   IntegerType(), False),
    StructField("FiscalQuarter",IntegerType(), False),
])

dates = pd.date_range("2014-01-01", "2026-12-31", freq="D")
rows = []
for d in dates:
    dt = d.date()
    rows.append((
        int(d.strftime("%Y%m%d")),
        dt,
        d.year, d.quarter, d.month,
        d.strftime("%B"),
        d.day,
        int(d.strftime("%W")),
        d.dayofweek + 1,          # 1=Mon … 7=Sun
        d.strftime("%A"),
        1 if d.dayofweek >= 5 else 0,
        1 if (d.year % 4 == 0 and (d.year % 100 != 0 or d.year % 400 == 0)) else 0,
        d.year + (1 if d.month >= 4 else 0),   # fiscal year starts April
        ((d.month - 4) % 12) // 3 + 1,         # fiscal quarter
    ))

# Create the DataFrame and temp view
df_dim_date = spark.createDataFrame(rows, schema=date_schema)
df_dim_date.createOrReplaceTempView("dim_date_tmp")

# Create or replace the Delta table from the temp view
spark.sql(f"CREATE OR REPLACE TABLE {DEMO_LAKEHOUSE}.dim_date USING DELTA AS SELECT * FROM dim_date_tmp")

print(f"  dim_date: {df_dim_date.count()} rows written")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

spark.sql(f"""
CREATE OR REPLACE TABLE {DEMO_LAKEHOUSE}.dim_customer USING DELTA AS
SELECT
    customer_id          AS CustomerKey,
    account_number       AS AccountNumber,
    first_name           AS FirstName,
    last_name            AS LastName,
    email                AS Email,
    phone                AS Phone,
    customer_type        AS CustomerType,
    status               AS Status,
    city                 AS City,
    province             AS Province,
    postal_code          AS PostalCode,
    LEFT(postal_code, 3) AS FSA,
    created_date         AS CreatedDate
FROM {DEMO_LAKEHOUSE}.customers
""")
print(f"  dim_customer: {spark.table(f'{DEMO_LAKEHOUSE}.dim_customer').count()} rows")

spark.sql(f"""
CREATE OR REPLACE TABLE {DEMO_LAKEHOUSE}.dim_product USING DELTA AS
SELECT
    product_id        AS ProductKey,
    product_code      AS ProductCode,
    product_name      AS ProductName,
    product_category  AS ProductCategory,
    billing_frequency AS BillingFrequency,
    base_price        AS BasePrice,
    is_active         AS IsActive,
    effective_date    AS EffectiveDate
FROM {DEMO_LAKEHOUSE}.products
""")
print(f"  dim_product: {spark.table(f'{DEMO_LAKEHOUSE}.dim_product').count()} rows")

spark.sql(f"""
CREATE OR REPLACE TABLE {DEMO_LAKEHOUSE}.dim_service_account USING DELTA AS
SELECT
    sa.service_account_id AS ServiceAccountKey,
    sa.customer_id        AS CustomerKey,
    sa.account_number     AS AccountNumber,
    sa.utility_type       AS UtilityType,
    sa.rate_class         AS RateClass,
    sa.distributor        AS Distributor,
    sa.status             AS Status,
    sa.service_address    AS ServiceAddress,
    sa.city               AS City,
    sa.postal_code        AS PostalCode,
    LEFT(sa.postal_code, 3) AS FSA,
    sa.opened_date        AS OpenedDate
FROM {DEMO_LAKEHOUSE}.service_accounts sa
""")
print(f"  dim_service_account: {spark.table(f'{DEMO_LAKEHOUSE}.dim_service_account').count()} rows")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

spark.sql(f"""
CREATE OR REPLACE TABLE {DEMO_LAKEHOUSE}.dim_equipment USING DELTA AS
SELECT
    e.equipment_id                                          AS EquipmentKey,
    e.service_account_id                                    AS ServiceAccountKey,
    e.equipment_type                                        AS EquipmentType,
    e.make                                                  AS Make,
    e.model                                                 AS Model,
    e.serial_number                                         AS SerialNumber,
    e.ownership_type                                        AS OwnershipType,
    e.fuel_type                                             AS FuelType,
    e.install_date                                          AS InstallDate,
    e.warranty_expiry                                       AS WarrantyExpiry,
    e.status                                                AS Status,
    CAST(DATE_FORMAT(e.install_date,   'yyyyMMdd') AS INT)  AS InstallDateKey,
    CAST(DATE_FORMAT(e.warranty_expiry,'yyyyMMdd') AS INT)  AS WarrantyExpiryDateKey,
    ROUND(DATEDIFF(CURRENT_DATE(), e.install_date) / 365.25, 1) AS AgeYears,
    CASE WHEN e.warranty_expiry >= CURRENT_DATE() THEN 1 ELSE 0 END AS IsUnderWarranty
FROM {DEMO_LAKEHOUSE}.equipment_registry e
""")
print(f"  dim_equipment: {spark.table(f'{DEMO_LAKEHOUSE}.dim_equipment').count()} rows")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

spark.sql(f"""
CREATE OR REPLACE TABLE {DEMO_LAKEHOUSE}.fct_billing USING DELTA AS
SELECT
    bt.transaction_id                                             AS TransactionKey,
    bt.contract_id                                                AS ContractKey,
    bt.service_account_id                                         AS ServiceAccountKey,
    sa.customer_id                                                AS CustomerKey,
    c.product_id                                                  AS ProductKey,
    CAST(DATE_FORMAT(bt.transaction_date, 'yyyyMMdd') AS INT)     AS TransactionDateKey,
    CAST(DATE_FORMAT(bt.due_date,         'yyyyMMdd') AS INT)     AS DueDateKey,
    bt.transaction_type                                           AS TransactionType,
    bt.amount                                                     AS Amount,
    bt.tax_amount                                                 AS TaxAmount,
    bt.amount + bt.tax_amount                                     AS TotalAmount,
    bt.payment_method                                             AS PaymentMethod,
    bt.status                                                     AS Status,
    bt.invoice_number                                             AS InvoiceNumber
FROM {DEMO_LAKEHOUSE}.billing_transactions bt
JOIN {DEMO_LAKEHOUSE}.service_accounts sa ON sa.service_account_id = bt.service_account_id
JOIN {DEMO_LAKEHOUSE}.contracts c         ON c.contract_id         = bt.contract_id
""")
print(f"  fct_billing: {spark.table(f'{DEMO_LAKEHOUSE}.fct_billing').count()} rows")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

spark.sql(f"""
CREATE OR REPLACE TABLE {DEMO_LAKEHOUSE}.fct_service_request USING DELTA AS
SELECT
    sr.request_id                                                  AS RequestKey,
    sr.service_account_id                                          AS ServiceAccountKey,
    sa.customer_id                                                 AS CustomerKey,
    sr.equipment_id                                                AS EquipmentKey,
    CAST(DATE_FORMAT(sr.created_date,   'yyyyMMdd') AS INT)        AS CreatedDateKey,
    CAST(DATE_FORMAT(sr.scheduled_date, 'yyyyMMdd') AS INT)        AS ScheduledDateKey,
    CAST(DATE_FORMAT(sr.completed_date, 'yyyyMMdd') AS INT)        AS CompletedDateKey,
    sr.request_type                                                AS RequestType,
    sr.priority                                                    AS Priority,
    sr.status                                                      AS Status,
    sr.description                                                 AS Description,
    sr.technician_id                                               AS TechnicianId,
    sr.resolution_notes                                            AS ResolutionNotes,
    CASE
        WHEN sr.status = 'Completed' AND sr.priority IN ('High','Emergency')
             AND sr.completed_date > sr.scheduled_date            THEN 1
        WHEN sr.status IN ('Open','InProgress') AND sr.priority IN ('High','Emergency')
             AND sr.scheduled_date < CURRENT_DATE()               THEN 1
        ELSE 0
    END                                                            AS IsSlaBreachFlag,
    CASE WHEN sr.completed_date IS NOT NULL
         THEN DATEDIFF(sr.completed_date, sr.created_date)
         ELSE NULL
    END                                                            AS DaysToComplete
FROM {DEMO_LAKEHOUSE}.service_requests sr
JOIN {DEMO_LAKEHOUSE}.service_accounts sa ON sa.service_account_id = sr.service_account_id
""")
print(f"  fct_service_request: {spark.table(f'{DEMO_LAKEHOUSE}.fct_service_request').count()} rows")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# fct_contract_month  (contract × monthly spine, with IsNew / IsChurn)
# ---------------------------------------------------------------------------

# Build the contract-month spine using billing_frequency from products
spark.sql(f"""
CREATE OR REPLACE TABLE {DEMO_LAKEHOUSE}.fct_contract_month USING DELTA AS
WITH months AS (
    SELECT EXPLODE(SEQUENCE(
        DATE '2023-01-01',
        DATE '2024-12-01',
        INTERVAL 1 MONTH
    )) AS BillingMonth
),
active_spine AS (
    SELECT
        c.contract_id,
        c.service_account_id,
        sa.customer_id,
        c.product_id,
        p.billing_frequency,
        c.monthly_amount     AS MonthlyAmount,
        c.contract_status    AS ContractStatus,
        c.start_date         AS ContractStartDate,
        c.cancellation_date  AS CancellationDate,
        m.BillingMonth
    FROM {DEMO_LAKEHOUSE}.contracts c
    JOIN {DEMO_LAKEHOUSE}.service_accounts sa ON sa.service_account_id = c.service_account_id
    JOIN {DEMO_LAKEHOUSE}.products p          ON p.product_id          = c.product_id
    CROSS JOIN months m
    WHERE p.billing_frequency = 'Monthly'
      AND m.BillingMonth >= DATE_TRUNC('MONTH', c.start_date)
      AND (c.cancellation_date IS NULL OR m.BillingMonth <= DATE_TRUNC('MONTH', c.cancellation_date))
)
SELECT
    contract_id                                                     AS ContractKey,
    service_account_id                                              AS ServiceAccountKey,
    customer_id                                                     AS CustomerKey,
    product_id                                                      AS ProductKey,
    BillingMonth,
    CAST(DATE_FORMAT(BillingMonth,       'yyyyMMdd') AS INT)        AS BillingMonthDateKey,
    CAST(DATE_FORMAT(ContractStartDate,  'yyyyMMdd') AS INT)        AS ContractStartDateKey,
    MonthlyAmount,
    ContractStatus,
    CASE WHEN DATE_TRUNC('MONTH', ContractStartDate) = BillingMonth  THEN 1 ELSE 0 END AS IsNew,
    CASE WHEN CancellationDate IS NOT NULL
              AND DATE_TRUNC('MONTH', CancellationDate) = BillingMonth THEN 1 ELSE 0 END AS IsChurn
FROM active_spine
""")

print(f"  fct_contract_month: {spark.table(f'{DEMO_LAKEHOUSE}.fct_contract_month').count()} rows")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

print("\n=== Star schema row counts ===")
dims  = ["dim_date", "dim_customer", "dim_product", "dim_equipment", "dim_service_account"]
facts = ["fct_billing", "fct_service_request", "fct_contract_month"]

print("  Dimensions:")
for t in dims:
    print(f"    {t:<30} {spark.table(f'{DEMO_LAKEHOUSE}.{t}').count():>6} rows")

print("  Facts:")
for t in facts:
    print(f"    {t:<30} {spark.table(f'{DEMO_LAKEHOUSE}.{t}').count():>6} rows")

print("\nStar schema ready.  Open BrookfieldEnercare.pbip in Power BI Desktop.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
