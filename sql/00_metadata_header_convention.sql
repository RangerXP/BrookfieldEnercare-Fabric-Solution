/*-----------------------------------------------------------------------------
    Brookfield Enercare — Metadata Header Convention
    File: 00_metadata_header_convention.sql

    Purpose
        Establish a single, machine-parseable comment block that every business
        view and stored procedure must carry. The extractor (02_extract_from_modules)
        reads these blocks; nothing else is treated as authoritative.

    Convention
        - The block must be the FIRST comment in the module body.
        - Tag prefix is '@' followed by the tag name, then ':'.
        - Tags may span multiple lines until the next '@tag:' or '*/'.
        - Repeated '@column' / '@kpi' / '@input' / '@output' tags are allowed.

    Tag reference
        @asset_type    : table | view | proc            (required)
        @business_name : human-friendly name            (required)
        @description   : 1-3 sentence purpose           (required)
        @owner         : team / DL                      (required)
        @steward       : individual responsible         (required)
        @domain        : Customer | Billing | Ops | ... (required)
        @grain         : one row per ...                (required for views)
        @refresh       : real-time | hourly | daily ... (required for views)
        @sensitivity   : Public | Internal | Confidential | HBI
        @glossary      : comma-separated glossary terms
        @column        : <name> | <description>         (one per column)
        @kpi           : <name> | <description> | <formula or column> (procs/views)
        @input         : <param> | <description>        (procs)
        @output        : <name>  | <description>        (procs)
        @upstream      : comma-separated objects this depends on (optional override)
        @notes         : free text
-----------------------------------------------------------------------------*/

-- =========================================================================
-- EXAMPLE 1: a view exposing a customer 360 grain
-- =========================================================================
CREATE OR ALTER VIEW dbo.vw_Customer360 AS
/*
@asset_type    : view
@business_name : Customer 360
@description   : One row per active residential customer with current plan,
                 lifetime value, and churn risk score. Use this for any
                 customer-level BI; do not join to dbo.Customer directly.
@owner         : Customer Analytics
@steward       : jane.doe@brookfieldenercare.com
@domain        : Customer
@grain         : one row per CustomerId where IsActive = 1
@refresh       : hourly (sourced from mirrored OLTP)
@sensitivity   : Confidential
@glossary      : Customer, Active Customer, Lifetime Value, Churn Risk
@column        : CustomerId        | Surrogate key for the customer dimension.
@column        : DisplayName       | Concatenation of FirstName + LastName, trimmed.
@column        : PlanCode          | Current rate plan code; FK to dbo.Plan.
@column        : LifetimeValueCAD  | Sum of net revenue to date, in CAD; from dbo.fn_LTV.
@column        : ChurnRiskScore    | Probability 0-1 from ML model v3 (refreshed nightly).
@upstream      : dbo.Customer, dbo.Plan, dbo.fn_LTV, ml.ChurnScore
*/
SELECT
    c.CustomerId,
    LTRIM(RTRIM(c.FirstName + ' ' + c.LastName)) AS DisplayName,
    p.PlanCode,
    dbo.fn_LTV(c.CustomerId)                    AS LifetimeValueCAD,
    s.ChurnRiskScore
FROM dbo.Customer  c
JOIN dbo.Plan      p ON p.PlanId = c.CurrentPlanId
LEFT JOIN ml.ChurnScore s ON s.CustomerId = c.CustomerId
WHERE c.IsActive = 1;
GO

-- =========================================================================
-- EXAMPLE 2: a stored procedure that computes a KPI used in reporting
-- =========================================================================
CREATE OR ALTER PROCEDURE billing.usp_MonthlyRecurringRevenue
    @AsOfDate DATE
AS
/*
@asset_type    : proc
@business_name : Monthly Recurring Revenue
@description   : Computes MRR for the month containing @AsOfDate using the
                 finance-approved revenue recognition rules (BE-FIN-2024-07).
                 Excludes one-time charges and prorated credits.
@owner         : Finance Engineering
@steward       : ravi.k@brookfieldenercare.com
@domain        : Billing
@sensitivity   : Confidential
@input         : @AsOfDate | Any date in the target month (UTC).
@output        : MRR_CAD   | Sum of normalized monthly recurring charges in CAD.
@output        : Customers | Count of distinct customers contributing to MRR.
@kpi           : MRR | Monthly Recurring Revenue per BE-FIN-2024-07 |
                 SUM(NormalizedMonthlyCharge) WHERE ChargeType = 'Recurring'
@glossary      : Monthly Recurring Revenue, Recurring Charge
@upstream      : dbo.BillingLine, dbo.RateCard, dbo.fn_NormalizeCharge
*/
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        SUM(dbo.fn_NormalizeCharge(bl.Amount, bl.PeriodDays)) AS MRR_CAD,
        COUNT(DISTINCT bl.CustomerId)                          AS Customers
    FROM dbo.BillingLine bl
    WHERE bl.ChargeType = 'Recurring'
      AND bl.PeriodMonth = EOMONTH(@AsOfDate);
END
GO
