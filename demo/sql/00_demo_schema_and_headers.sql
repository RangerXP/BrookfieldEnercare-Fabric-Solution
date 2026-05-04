-- ============================================================
-- ENERCARE DEMO DATA MODEL
-- Dummy schema for metadata pipeline development
--
-- Purpose : End-to-end demo of the governance pipeline described
--           in README.md.  All views carry the structured header
--           convention so the Python extractor in nb_02 can parse
--           them the same way it will parse production modules.
--
-- Replace : JDBC connection in nb_02 → sys.sql_modules to ingest
--           the real Enercare OLTP schema (no changes to extractor
--           logic required).
-- ============================================================

-- ============================================================
-- 0. SCHEMA
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'demo')
    EXEC('CREATE SCHEMA demo');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'meta')
    EXEC('CREATE SCHEMA meta');
GO


-- ============================================================
-- 1. BASE TABLES  (no header convention — tables are catalogued
--                  by Purview scan, not header extraction)
-- ============================================================

CREATE TABLE demo.customers (
    customer_id         INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    account_number      VARCHAR(20)     NOT NULL UNIQUE,
    first_name          VARCHAR(100)    NOT NULL,
    last_name           VARCHAR(100)    NOT NULL,
    email               VARCHAR(255)        NULL,
    phone               VARCHAR(20)         NULL,
    customer_type       VARCHAR(30)     NOT NULL,   -- Residential | Commercial | MUR
    status              VARCHAR(20)     NOT NULL,   -- Active | Inactive | Suspended
    city                VARCHAR(100)        NULL,
    province            CHAR(2)         NOT NULL DEFAULT 'ON',
    postal_code         CHAR(7)             NULL,
    created_date        DATE            NOT NULL,
    last_modified_utc   DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE demo.service_accounts (
    service_account_id  INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    customer_id         INT             NOT NULL REFERENCES demo.customers(customer_id),
    account_number      VARCHAR(20)     NOT NULL UNIQUE,
    utility_type        VARCHAR(30)     NOT NULL,   -- Natural Gas | Electricity | HVAC | Water Heater
    rate_class          VARCHAR(30)         NULL,   -- Residential | General Commercial
    distributor         VARCHAR(100)        NULL,   -- Enbridge Gas | Toronto Hydro | Hydro One
    status              VARCHAR(20)     NOT NULL,   -- Active | Closed | Suspended
    service_address     VARCHAR(255)        NULL,
    city                VARCHAR(100)        NULL,
    postal_code         CHAR(7)             NULL,
    opened_date         DATE            NOT NULL,
    closed_date         DATE                NULL,
    last_modified_utc   DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE demo.products (
    product_id          INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    product_code        VARCHAR(20)     NOT NULL UNIQUE,
    product_name        VARCHAR(200)    NOT NULL,
    product_category    VARCHAR(50)     NOT NULL,   -- Rental | Protection | SmartHome | Cooling | Heating
    billing_frequency   VARCHAR(20)     NOT NULL,   -- Monthly | Annual | OneTime
    base_price          DECIMAL(10,2)   NOT NULL,
    is_active           BIT             NOT NULL DEFAULT 1,
    effective_date      DATE            NOT NULL,
    end_date            DATE                NULL
);
GO

CREATE TABLE demo.contracts (
    contract_id         INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    service_account_id  INT             NOT NULL REFERENCES demo.service_accounts(service_account_id),
    product_id          INT             NOT NULL REFERENCES demo.products(product_id),
    contract_status     VARCHAR(20)     NOT NULL,   -- Active | Cancelled | Expired | Pending
    start_date          DATE            NOT NULL,
    end_date            DATE                NULL,
    monthly_amount      DECIMAL(10,2)   NOT NULL,
    auto_renew          BIT             NOT NULL DEFAULT 1,
    cancellation_date   DATE                NULL,
    cancellation_reason VARCHAR(200)        NULL,
    last_modified_utc   DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE demo.equipment_registry (
    equipment_id        INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    service_account_id  INT             NOT NULL REFERENCES demo.service_accounts(service_account_id),
    equipment_type      VARCHAR(50)     NOT NULL,   -- Water Heater | Furnace | Central AC | Heat Pump | Smart Thermostat
    make                VARCHAR(100)        NULL,   -- Rheem | Bradford White | Lennox | Carrier | ecobee
    model               VARCHAR(100)        NULL,
    serial_number       VARCHAR(50)         NULL,
    ownership_type      VARCHAR(20)     NOT NULL,   -- Rental | Customer-Owned
    fuel_type           VARCHAR(20)         NULL,   -- Natural Gas | Electric | Propane
    install_date        DATE                NULL,
    warranty_expiry     DATE                NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'Active',  -- Active | Decommissioned | Replaced
    last_modified_utc   DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE demo.service_requests (
    request_id          INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    service_account_id  INT             NOT NULL REFERENCES demo.service_accounts(service_account_id),
    equipment_id        INT                 NULL REFERENCES demo.equipment_registry(equipment_id),
    request_type        VARCHAR(50)     NOT NULL,   -- Installation | Emergency Repair | Maintenance | Inspection | Upgrade
    priority            VARCHAR(20)     NOT NULL,   -- Low | Medium | High | Emergency
    status              VARCHAR(20)     NOT NULL,   -- Open | InProgress | Completed | Cancelled
    description         VARCHAR(500)        NULL,
    created_date        DATETIME2       NOT NULL,
    scheduled_date      DATE                NULL,
    completed_date      DATETIME2           NULL,
    technician_id       INT                 NULL,
    resolution_notes    VARCHAR(1000)       NULL,
    last_modified_utc   DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE demo.billing_transactions (
    transaction_id      INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    contract_id         INT             NOT NULL REFERENCES demo.contracts(contract_id),
    service_account_id  INT             NOT NULL REFERENCES demo.service_accounts(service_account_id),
    transaction_type    VARCHAR(30)     NOT NULL,   -- MonthlyCharge | OneTimeCharge | Payment | Credit | Adjustment
    transaction_date    DATE            NOT NULL,
    due_date            DATE                NULL,
    amount              DECIMAL(10,2)   NOT NULL,
    tax_amount          DECIMAL(10,2)       NULL DEFAULT 0,
    payment_method      VARCHAR(30)         NULL,   -- CreditCard | DirectDebit | Cheque | Online
    status              VARCHAR(20)     NOT NULL,   -- Pending | Posted | Paid | Failed | Reversed
    invoice_number      VARCHAR(50)         NULL,
    last_modified_utc   DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);
GO


-- ============================================================
-- 2. ANALYTICAL VIEWS  (full header convention — parsed by extractor)
--    Each view maps to a phase in the metadata pipeline:
--      Phase 0 → adopt header convention
--      Phase 1 → extractor reads these definitions
--      Phase 4 → Fabric Delta comments come from @column tags
--      Phase 5 → Purview descriptions come from @description / @column
-- ============================================================

/*
  @asset_type:    view
  @business_name: Customer 360
  @description:   Unified customer profile combining account details, active
                  contracts, equipment count, and lifetime billing value.
                  Primary analytical surface for customer success and
                  retention teams.  One row per customer.
  @owner:         Data & Analytics
  @steward:       analytics@enercare.ca
  @domain:        Customer
  @grain:         One row per customer (customer_id)
  @refresh:       real-time (Direct Lake)
  @sensitivity:   Confidential – PII
  @glossary:      Customer; Contract; LifetimeValue; ChurnRisk
  @upstream:      demo.customers | demo.service_accounts | demo.contracts | demo.billing_transactions

  @column customer_id:           Surrogate key for the customer record
  @column account_number:        External-facing identifier used in all customer communications
  @column full_name:             Concatenated first + last name; use display-only, not as a join key
  @column customer_type:         Segmentation bucket: Residential | Commercial | MUR
  @column status:                Current lifecycle state of the account
  @column city:                  City of the customer's primary service address
  @column postal_code:           Full postal code; first 3 chars = FSA used for geo-clustering
  @column active_contract_count: Count of non-cancelled, non-expired contracts as of query date
  @column total_active_equipment: Active equipment items registered across all service accounts
  @column lifetime_value:        Sum of MonthlyCharge + OneTimeCharge (status=Posted) since account open; CAD
  @column avg_monthly_spend:     Mean of monthly charges over the trailing 12 months; NULL if tenure < 12 months
  @column first_contract_date:   Date of earliest contract; used as a proxy for customer tenure
  @column last_service_date:     Most recent completed service request; NULL if no service history
  @column tenure_months:         Months between created_date and today; used for cohort analysis

  @kpi active_contract_count:    metric | COUNT(contracts WHERE status = Active) | non-negative integer
  @kpi lifetime_value:           metric | SUM(billing WHERE type IN (MonthlyCharge,OneTimeCharge) AND status=Posted) | CAD, 2 dp
  @kpi avg_monthly_spend:        metric | lifetime_value / NULLIF(tenure_months,0) | CAD, 2 dp
  @kpi tenure_months:            metric | DATEDIFF(MONTH, created_date, GETDATE()) | integer months

  @notes: Excludes test/internal accounts (customer_type <> 'Internal').
          Lifetime value uses posted transactions only — excludes payments and credits.
*/
CREATE OR ALTER VIEW demo.vw_customer_360 AS
SELECT
    c.customer_id,
    c.account_number,
    c.first_name + ' ' + c.last_name                                       AS full_name,
    c.customer_type,
    c.status,
    c.city,
    c.postal_code,
    c.created_date,
    DATEDIFF(MONTH, c.created_date, GETDATE())                             AS tenure_months,
    COUNT(DISTINCT CASE WHEN ct.contract_status = 'Active'
                        THEN ct.contract_id END)                           AS active_contract_count,
    COUNT(DISTINCT CASE WHEN eq.status = 'Active'
                        THEN eq.equipment_id END)                          AS total_active_equipment,
    ISNULL(SUM(CASE WHEN bt.transaction_type IN ('MonthlyCharge','OneTimeCharge')
                     AND bt.status = 'Posted'
                    THEN bt.amount ELSE 0 END), 0)                         AS lifetime_value,
    CASE WHEN DATEDIFF(MONTH, c.created_date, GETDATE()) >= 12
         THEN ISNULL(SUM(CASE WHEN bt.transaction_type = 'MonthlyCharge'
                               AND bt.status = 'Posted'
                               AND bt.transaction_date >= DATEADD(MONTH,-12,CAST(GETDATE() AS DATE))
                              THEN bt.amount ELSE 0 END), 0)
              / NULLIF(12.0, 0)
         ELSE NULL
    END                                                                    AS avg_monthly_spend,
    MIN(ct.start_date)                                                     AS first_contract_date,
    MAX(sr.completed_date)                                                 AS last_service_date
FROM       demo.customers c
LEFT JOIN  demo.service_accounts sa    ON sa.customer_id        = c.customer_id
LEFT JOIN  demo.contracts ct           ON ct.service_account_id = sa.service_account_id
LEFT JOIN  demo.equipment_registry eq  ON eq.service_account_id = sa.service_account_id
LEFT JOIN  demo.billing_transactions bt ON bt.service_account_id = sa.service_account_id
LEFT JOIN  demo.service_requests sr    ON sr.service_account_id = sa.service_account_id
WHERE c.customer_type <> 'Internal'
GROUP BY
    c.customer_id, c.account_number,
    c.first_name, c.last_name,
    c.customer_type, c.status,
    c.city, c.postal_code, c.created_date;
GO


/*
  @asset_type:    view
  @business_name: Monthly Recurring Revenue by Product
  @description:   Calculates MRR contribution per contract for each calendar
                  month.  Supports Finance and Strategy reporting on revenue
                  growth, churn, and product mix.  Covers all active and
                  recently cancelled contracts from 2023-01-01 onward.
  @owner:         Finance Analytics
  @steward:       finance.analytics@enercare.ca
  @domain:        Revenue
  @grain:         One row per (contract_id, billing_month)
  @refresh:       daily (scheduled Lakehouse refresh)
  @sensitivity:   Internal
  @glossary:      MRR; Contract; Churn; Expansion; ARR
  @upstream:      demo.contracts | demo.products | demo.billing_transactions | demo.service_accounts

  @column contract_id:      Unique contract identifier; join key to demo.contracts
  @column service_account_id: Owning service account; join key to demo.service_accounts
  @column product_name:     Friendly product name from the product master
  @column product_category: High-level revenue category: Rental | Protection | SmartHome | Cooling | Heating
  @column billing_month:    First day of the reporting month (YYYY-MM-01); use for time-series grain
  @column contract_status:  Contract state at query time (not month-specific; use for current-state filters)
  @column monthly_amount:   MRR contribution of this contract in CAD; annualised contracts divided by 12
  @column is_new:           1 if this is the first billing month for this contract (acquisition)
  @column is_churn:         1 if this contract was cancelled in this billing month

  @kpi monthly_amount:      metric | SUM(contracts.monthly_amount WHERE is_active_in_month) | CAD MRR
  @kpi is_churn:            metric | COUNT(contracts WHERE cancellation_date IN billing_month) | integer; track monthly
  @kpi is_new:              metric | COUNT(contracts WHERE start_date IN billing_month) | integer; track monthly

  @notes: MRR spine generated for Jan 2023 – Dec 2024 (24 months).
          Annualised contracts: monthly_amount = base_price / 12.
          Cancellations are included in the month they were cancelled.
*/
CREATE OR ALTER VIEW demo.vw_monthly_revenue AS
WITH months AS (
    SELECT CAST(DATEADD(MONTH, n, '2023-01-01') AS DATE) AS billing_month
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),
                 (12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23)) t(n)
)
SELECT
    ct.contract_id,
    ct.service_account_id,
    p.product_name,
    p.product_category,
    m.billing_month,
    ct.contract_status,
    CASE p.billing_frequency
        WHEN 'Annual'  THEN ct.monthly_amount / 12.0
        ELSE ct.monthly_amount
    END                                                                     AS monthly_amount,
    CASE WHEN DATEDIFF(MONTH, ct.start_date, m.billing_month) = 0
         THEN 1 ELSE 0 END                                                  AS is_new,
    CASE WHEN ct.cancellation_date IS NOT NULL
          AND m.billing_month = DATEFROMPARTS(
                  YEAR(ct.cancellation_date),
                  MONTH(ct.cancellation_date), 1)
         THEN 1 ELSE 0 END                                                  AS is_churn
FROM       demo.contracts ct
JOIN       demo.products p   ON p.product_id    = ct.product_id
JOIN       months m          ON m.billing_month >= DATEFROMPARTS(
                                     YEAR(ct.start_date), MONTH(ct.start_date), 1)
                             AND (ct.end_date IS NULL
                                  OR m.billing_month <= DATEFROMPARTS(
                                         YEAR(ct.end_date), MONTH(ct.end_date), 1))
WHERE ct.contract_status IN ('Active', 'Cancelled', 'Expired');
GO


/*
  @asset_type:    view
  @business_name: Equipment Health Dashboard
  @description:   Active equipment inventory enriched with age, warranty
                  status, and service history.  Supports proactive maintenance
                  planning, warranty renewal campaigns, and field operations
                  scheduling.
  @owner:         Field Operations
  @steward:       operations.data@enercare.ca
  @domain:        Operations
  @grain:         One row per active equipment_id
  @refresh:       daily
  @sensitivity:   Internal
  @glossary:      Equipment; Warranty; ServiceHistory; MTBF; Rental
  @upstream:      demo.equipment_registry | demo.service_accounts | demo.customers | demo.service_requests

  @column equipment_id:              Surrogate key for the equipment record
  @column equipment_type:            Category: Water Heater | Furnace | Central AC | Heat Pump | Smart Thermostat
  @column make:                      Manufacturer name (e.g. Rheem, Bradford White, Lennox, Carrier)
  @column model:                     Manufacturer model number or name
  @column serial_number:             Factory serial; used for warranty claims and parts ordering
  @column ownership_type:            Rental = Enercare owns asset; Customer-Owned = Enercare services only
  @column fuel_type:                 Energy source: Natural Gas | Electric | Propane
  @column install_date:              Date equipment was installed at the service address
  @column age_years:                 Decimal years since install_date; NULL if install_date is NULL
  @column is_under_warranty:         1 if warranty_expiry >= today; 0 if expired or NULL
  @column days_to_warranty_expiry:   Positive = days remaining; negative = days past expiry; NULL if no warranty date
  @column service_request_count:     Total lifetime service requests against this equipment unit
  @column last_service_type:         Most recent service request type (completed requests only)
  @column last_service_date:         Date of the most recent completed service visit
  @column customer_account_number:   Customer's external account number; used for CS lookup
  @column city:                      City of the service address

  @kpi age_years:              metric | DATEDIFF(day,install_date,GETDATE()) / 365.25 | decimal years
  @kpi service_request_count:  metric | COUNT(service_requests WHERE equipment_id = equipment_id) | integer
  @kpi is_under_warranty:      metric | SUM(is_under_warranty) / COUNT(*) | warranty coverage rate 0-1

  @notes: Filters to eq.status = 'Active' only.
          age_years and days_to_warranty_expiry are NULL when install_date / warranty_expiry are NULL.
*/
CREATE OR ALTER VIEW demo.vw_equipment_health AS
SELECT
    eq.equipment_id,
    eq.equipment_type,
    eq.make,
    eq.model,
    eq.serial_number,
    eq.ownership_type,
    eq.fuel_type,
    eq.install_date,
    ROUND(DATEDIFF(DAY, eq.install_date, GETDATE()) / 365.25, 1)           AS age_years,
    CASE WHEN eq.warranty_expiry >= CAST(GETDATE() AS DATE)
         THEN 1 ELSE 0 END                                                  AS is_under_warranty,
    DATEDIFF(DAY, CAST(GETDATE() AS DATE), eq.warranty_expiry)             AS days_to_warranty_expiry,
    sa.service_account_id,
    sa.utility_type,
    c.customer_id,
    c.account_number                                                        AS customer_account_number,
    c.city,
    COUNT(sr.request_id)                                                    AS service_request_count,
    MAX(CASE WHEN sr.status = 'Completed'
             THEN sr.request_type END)                                      AS last_service_type,
    MAX(sr.completed_date)                                                  AS last_service_date
FROM       demo.equipment_registry eq
JOIN       demo.service_accounts sa    ON sa.service_account_id = eq.service_account_id
JOIN       demo.customers c            ON c.customer_id          = sa.customer_id
LEFT JOIN  demo.service_requests sr    ON sr.equipment_id        = eq.equipment_id
WHERE eq.status = 'Active'
GROUP BY
    eq.equipment_id, eq.equipment_type, eq.make, eq.model, eq.serial_number,
    eq.ownership_type, eq.fuel_type, eq.install_date, eq.warranty_expiry,
    sa.service_account_id, sa.utility_type,
    c.customer_id, c.account_number, c.city;
GO


/*
  @asset_type:    view
  @business_name: Open Service Backlog
  @description:   All open and in-progress service requests enriched with
                  SLA status, customer context, and equipment type.  Primary
                  operational dashboard for dispatch and service coordination.
                  Real-time Direct Lake surface; does not require scheduled
                  refresh.
  @owner:         Field Operations
  @steward:       operations.data@enercare.ca
  @domain:        Operations
  @grain:         One row per open or in-progress service request (request_id)
  @refresh:       real-time (Direct Lake)
  @sensitivity:   Internal
  @glossary:      ServiceRequest; SLA; Priority; Dispatch; FieldOps
  @upstream:      demo.service_requests | demo.service_accounts | demo.customers | demo.equipment_registry

  @column request_id:         Unique service request identifier
  @column request_type:       Work category: Installation | Emergency Repair | Maintenance | Inspection | Upgrade
  @column priority:           Urgency tier determining SLA: Low | Medium | High | Emergency
  @column status:             Current workflow state: Open | InProgress
  @column description:        Free-text description of the reported issue
  @column created_date:       UTC timestamp when the request was logged
  @column scheduled_date:     Planned service visit date; NULL if not yet scheduled
  @column age_hours:          Elapsed hours from created_date to now; basis for SLA monitoring
  @column sla_target_hours:   SLA commitment in hours by priority: Emergency=4, High=24, Medium=72, Low=168
  @column is_sla_breach:      1 if age_hours exceeds sla_target_hours and request is still open
  @column customer_account:   Customer account number; used for customer service lookup
  @column city:               City of the service address
  @column equipment_type:     Type of equipment associated with the request (NULL if not equipment-related)
  @column technician_id:      Assigned technician identifier; NULL if unassigned

  @kpi is_sla_breach:         metric | COUNT(requests WHERE is_sla_breach=1) | integer; alert threshold > 5
  @kpi age_hours:             metric | AVG(age_hours WHERE status = Open) | hours; operational health indicator

  @notes: Filters to status IN ('Open','InProgress') only.
          SLA targets: Emergency 4 h, High 24 h, Medium 72 h, Low 168 h.
          Breach flag does not clear automatically when technician is assigned — only on completion.
*/
CREATE OR ALTER VIEW demo.vw_service_backlog AS
SELECT
    sr.request_id,
    sr.request_type,
    sr.priority,
    sr.status,
    sr.description,
    sr.created_date,
    sr.scheduled_date,
    ROUND(DATEDIFF(MINUTE, sr.created_date, GETUTCDATE()) / 60.0, 1)       AS age_hours,
    CASE sr.priority
        WHEN 'Emergency' THEN 4
        WHEN 'High'      THEN 24
        WHEN 'Medium'    THEN 72
        ELSE                  168
    END                                                                     AS sla_target_hours,
    CASE WHEN ROUND(DATEDIFF(MINUTE, sr.created_date, GETUTCDATE()) / 60.0, 1)
              > CASE sr.priority
                    WHEN 'Emergency' THEN 4
                    WHEN 'High'      THEN 24
                    WHEN 'Medium'    THEN 72
                    ELSE 168
                END
         THEN 1 ELSE 0 END                                                  AS is_sla_breach,
    c.account_number                                                        AS customer_account,
    c.city,
    eq.equipment_type,
    sr.technician_id
FROM      demo.service_requests sr
JOIN      demo.service_accounts sa    ON sa.service_account_id = sr.service_account_id
JOIN      demo.customers c            ON c.customer_id          = sa.customer_id
LEFT JOIN demo.equipment_registry eq  ON eq.equipment_id        = sr.equipment_id
WHERE sr.status IN ('Open', 'InProgress');
GO


-- ============================================================
-- 3. META TABLES  (canonical metadata store — same DDL as
--    sql/01_create_metadata_tables.sql but scoped to demo schema
--    so the full-pipeline demo is self-contained)
-- ============================================================

CREATE TABLE meta.AssetMetadata (
    AssetId             INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    SchemaName          VARCHAR(128)    NOT NULL,
    ObjectName          VARCHAR(128)    NOT NULL,
    ObjectType          VARCHAR(20)     NOT NULL,   -- TABLE | VIEW | PROCEDURE | FUNCTION
    BusinessName        VARCHAR(200)        NULL,
    Description         NVARCHAR(MAX)       NULL,
    Owner               VARCHAR(200)        NULL,
    Steward             VARCHAR(200)        NULL,
    Domain              VARCHAR(100)        NULL,
    Grain               VARCHAR(500)        NULL,
    RefreshFrequency    VARCHAR(100)        NULL,
    Sensitivity         VARCHAR(100)        NULL,
    GlossaryTerms       NVARCHAR(MAX)       NULL,
    UpstreamAssets      NVARCHAR(MAX)       NULL,
    Notes               NVARCHAR(MAX)       NULL,
    DefinitionHash      CHAR(64)            NULL,   -- SHA2_256 for drift detection
    IsDraft             BIT             NOT NULL DEFAULT 0,
    LastExtractedUtc    DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_AssetMetadata UNIQUE (SchemaName, ObjectName)
);
GO

CREATE TABLE meta.ColumnMetadata (
    ColumnId            INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    AssetId             INT             NOT NULL REFERENCES meta.AssetMetadata(AssetId),
    ColumnName          VARCHAR(128)    NOT NULL,
    Description         NVARCHAR(MAX)       NULL,
    DataType            VARCHAR(50)         NULL,
    IsNullable          BIT                 NULL,
    UpstreamColumn      VARCHAR(256)        NULL,   -- schema.table.column lineage
    IsDraft             BIT             NOT NULL DEFAULT 0,
    LastExtractedUtc    DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_ColumnMetadata UNIQUE (AssetId, ColumnName)
);
GO

CREATE TABLE meta.KpiMetadata (
    KpiId               INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
    AssetId             INT             NOT NULL REFERENCES meta.AssetMetadata(AssetId),
    KpiName             VARCHAR(128)    NOT NULL,
    KpiType             VARCHAR(50)         NULL,   -- metric | dimension | ratio
    Formula             NVARCHAR(MAX)       NULL,
    Unit                VARCHAR(100)        NULL,
    IsDraft             BIT             NOT NULL DEFAULT 0,
    LastExtractedUtc    DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_KpiMetadata UNIQUE (AssetId, KpiName)
);
GO
