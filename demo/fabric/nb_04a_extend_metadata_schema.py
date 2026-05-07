# Fabric Notebook: nb_04a_extend_metadata_schema.py
# Gaps: G1-3, G1-4, G1-5, G1-7, G2-1, G2-2
# Purpose: Extend lh_metadata schema and seed certified KPI definitions
#
# Run order: after nb_02_metadata_pipeline_demo (lh_metadata must exist)
# Lakehouse: set lh_metadata as default lakehouse before running
#
# DEMO_MODE = True  → print all SQL/data; no writes to Delta
# DEMO_MODE = False → execute all ALTER / CREATE / INSERT statements

# CELL 1 — Configuration
# ──────────────────────────────────────────────────────────────────────────
DEMO_MODE = True          # TODO: set False to execute against lh_metadata

METADATA_LAKEHOUSE = "lh_metadata"
CERTIFIED_BY       = "Christopher Dingle"
CERTIFIED_DATE     = "2026-05-06"
MODEL_NAME         = "BrookfieldEnercare"

print(f"nb_04a | DEMO_MODE={DEMO_MODE} | lakehouse={METADATA_LAKEHOUSE}")


# CELL 2 — Extend kpi_metadata: add certification + call-center columns
# G1-3, G2-1
# ──────────────────────────────────────────────────────────────────────────
# Adds 10 columns to the existing kpi_metadata Delta table.
# Uses ALTER TABLE — does NOT drop or recreate; existing rows keep their values.

sql_alter_kpi = f"""
ALTER TABLE {METADATA_LAKEHOUSE}.kpi_metadata
ADD COLUMNS (
    KPICode            STRING,
    IsCertified        INT      DEFAULT 0,
    Version            INT      DEFAULT 1,
    PreviousFormula    STRING,
    CertifiedBy        STRING,
    CertifiedDate      DATE,
    TargetValue        DOUBLE,
    WarningThreshold   DOUBLE,
    CriticalThreshold  DOUBLE,
    UnitType           STRING
)
""".strip()

if DEMO_MODE:
    print("[DEMO_MODE] Would execute:\n")
    print(sql_alter_kpi)
else:
    spark.sql(sql_alter_kpi)
    print(f"kpi_metadata extended: 10 columns added")


# CELL 3 — Create ai_metadata table
# G1-4: stores verified answers, AI instructions, term mappings per model
# ──────────────────────────────────────────────────────────────────────────

sql_create_ai_metadata = f"""
CREATE TABLE IF NOT EXISTS {METADATA_LAKEHOUSE}.ai_metadata (
    RecordID       INT,
    ModelName      STRING,
    RecordType     STRING    COMMENT 'verified_answer | ai_instruction | term_mapping',
    TriggerText    STRING    COMMENT 'Question phrase or term that activates this record',
    ResponseText   STRING    COMMENT 'Verified answer text or AI instruction content',
    LinkedKPICode  STRING,
    IsDraft        INT       DEFAULT 1,
    CreatedDate    DATE
)
USING DELTA
COMMENT 'Copilot AI configuration — verified answers, instructions, term mappings'
""".strip()

if DEMO_MODE:
    print("[DEMO_MODE] Would execute:\n")
    print(sql_create_ai_metadata)
else:
    spark.sql(sql_create_ai_metadata)
    print("ai_metadata table created")


# CELL 4 — Create data_owners table
# G1-5: owner and steward registry per domain
# ──────────────────────────────────────────────────────────────────────────

sql_create_data_owners = f"""
CREATE TABLE IF NOT EXISTS {METADATA_LAKEHOUSE}.data_owners (
    Domain        STRING    COMMENT 'Business domain (Revenue, Customer, Operations, Call Center, Retention, Field Operations)',
    OwnerName     STRING,
    OwnerEmail    STRING,
    StewardName   STRING,
    StewardEmail  STRING
)
USING DELTA
COMMENT 'Domain data ownership registry — drives steward approval workflow (G9)'
""".strip()

if DEMO_MODE:
    print("[DEMO_MODE] Would execute:\n")
    print(sql_create_data_owners)
else:
    spark.sql(sql_create_data_owners)
    print("data_owners table created")


# CELL 5 — Create lineage_edges table
# G1-7: source-to-target graph used by nb_06_purview_lineage.py (G7)
# ──────────────────────────────────────────────────────────────────────────

sql_create_lineage = f"""
CREATE TABLE IF NOT EXISTS {METADATA_LAKEHOUSE}.lineage_edges (
    EdgeID         INT       COMMENT 'Monotonic edge identifier',
    SourceQName    STRING    COMMENT 'Purview qualified name of upstream asset',
    TargetQName    STRING    COMMENT 'Purview qualified name of downstream asset',
    ProcessName    STRING    COMMENT 'Notebook or pipeline performing the transform',
    TransformType  STRING    COMMENT 'mirror | notebook | dataflow | direct_lake'
)
USING DELTA
COMMENT 'Source-to-target lineage graph — consumed by nb_06_purview_lineage.py'
""".strip()

if DEMO_MODE:
    print("[DEMO_MODE] Would execute:\n")
    print(sql_create_lineage)
else:
    spark.sql(sql_create_lineage)
    print("lineage_edges table created")


# CELL 6 — Seed kpi_metadata: Set A — 12 existing DAX measures
# G2-2: baseline population; IsCertified=0 pending business sign-off
# ──────────────────────────────────────────────────────────────────────────

from pyspark.sql import Row
from pyspark.sql.types import (StructType, StructField, StringType,
                                IntegerType, DoubleType, DateType)
from datetime import date

existing_measures = [
    # name                   kpi_code                    domain        formula (DAX)
    ("Total MRR",            "total_mrr",            "Revenue",
     'CALCULATE(SUM(fct_billing[Amount]), fct_billing[TransactionType] = "MonthlyCharge", fct_billing[Status] = "Posted")'),
    ("New MRR",              "new_mrr",              "Revenue",
     "SUMX(FILTER(fct_contract_month, fct_contract_month[IsNew] = 1), fct_contract_month[MonthlyAmount])"),
    ("Churned MRR",          "churned_mrr",          "Revenue",
     "SUMX(FILTER(fct_contract_month, fct_contract_month[IsChurn] = 1), fct_contract_month[MonthlyAmount])"),
    ("Net MRR Change",       "net_mrr_change",       "Revenue",
     "[New MRR] - [Churned MRR]"),
    ("Active Customer Count","active_customer_count", "Customer",
     'CALCULATE(COUNTROWS(dim_customer), dim_customer[Status] = "Active")'),
    ("Active Contract Count","active_contract_count", "Customer",
     'CALCULATE(COUNTROWS(fct_contract_month), fct_contract_month[ContractStatus] = "Active")'),
    ("Avg Lifetime Value",   "avg_lifetime_value",   "Customer",
     'AVERAGEX(dim_customer, CALCULATE(SUMX(FILTER(fct_billing, fct_billing[Status] = "Posted"), fct_billing[Amount])))'),
    ("Avg Tenure Months",    "avg_tenure_months",    "Customer",
     "AVERAGEX(dim_customer, DATEDIFF(dim_customer[CreatedDate], TODAY(), MONTH))"),
    ("SLA Breach Count",     "sla_breach_count",     "Operations",
     "SUMX(fct_service_request, fct_service_request[IsSlaBreachFlag])"),
    ("SLA Compliance Rate",  "sla_compliance_rate",  "Operations",
     "DIVIDE(COUNTROWS(fct_service_request) - [SLA Breach Count], COUNTROWS(fct_service_request))"),
    ("Warranty Coverage Rate","warranty_coverage_rate","Operations",
     "DIVIDE(SUMX(dim_equipment, dim_equipment[IsUnderWarranty]), COUNTROWS(dim_equipment))"),
    ("Avg Equipment Age Years","avg_equipment_age_years","Operations",
     "AVERAGEX(dim_equipment, dim_equipment[AgeYears])"),
]

rows_set_a = []
for name, code, domain, formula in existing_measures:
    rows_set_a.append(Row(
        KPIName         = name,
        Formula         = formula,
        Description     = f"{name} — DAX measure from BrookfieldEnercare semantic model. Pending business certification.",
        Domain          = domain,
        Owner           = "analytics@enercare.ca",
        IsDraft         = 0,
        KPICode         = code,
        IsCertified     = 0,
        Version         = 1,
        PreviousFormula = None,
        CertifiedBy     = None,
        CertifiedDate   = None,
        TargetValue     = None,
        WarningThreshold= None,
        CriticalThreshold= None,
        UnitType        = "currency" if "MRR" in name or "Value" in name else
                          "count"    if "Count" in name else
                          "percentage" if "Rate" in name else
                          "decimal"
    ))

df_set_a = spark.createDataFrame(rows_set_a)

if DEMO_MODE:
    print(f"[DEMO_MODE] Set A — {len(rows_set_a)} existing DAX measures (IsCertified=0):\n")
    df_set_a.select("KPIName", "KPICode", "Domain", "IsCertified", "UnitType").show(truncate=False)
else:
    existing_count = spark.sql(
        f"SELECT COUNT(*) AS n FROM {METADATA_LAKEHOUSE}.kpi_metadata WHERE KPICode IS NOT NULL"
    ).first()["n"]
    if existing_count > 0:
        print(f"Skipping Set A seed — {existing_count} KPI rows already present")
    else:
        df_set_a.write.format("delta").mode("append").option("mergeSchema", "true") \
                .saveAsTable(f"{METADATA_LAKEHOUSE}.kpi_metadata")
        print(f"kpi_metadata seeded: {len(rows_set_a)} existing DAX measures")


# CELL 7 — Seed kpi_metadata: Set B — 5 call center KPIs
# G2-2: pre-certified call center KPIs from kpi-definitions.json
# ──────────────────────────────────────────────────────────────────────────

cc_kpi_defs = [
    {
        "KPIName":    "First Contact Resolution",
        "KPICode":    "FCR",
        "Domain":     "Call Center",
        "Owner":      "ranbir.singh@enercare.ca",
        "Formula":    'DIVIDE(CALCULATE(COUNTROWS(fct_cc_interactions), fct_cc_interactions[fcr_flag] = 1), COUNTROWS(fct_cc_interactions))',
        "Description": (
            "Percentage of customer interactions resolved without a follow-up within 5 business days. "
            "An interaction is resolved if no subsequent inbound contact occurs from the same customer "
            "about the same issue within the window. Target: 78%."
        ),
        "TargetValue":     0.78,
        "WarningThreshold":0.72,
        "CriticalThreshold":0.65,
        "UnitType":   "percentage",
    },
    {
        "KPIName":    "Customer Satisfaction Score",
        "KPICode":    "CSAT",
        "Domain":     "Call Center",
        "Owner":      "ranbir.singh@enercare.ca",
        "Formula":    "AVERAGE(fct_cc_interactions[csat_score])",
        "Description": (
            "Average post-call IVR survey score on a 1–5 scale (5 = very satisfied). "
            "Survey is offered to all inbound calls; response rate ~22%. "
            "Score is weighted by queue type for aggregate reporting. Target: 4.2."
        ),
        "TargetValue":      4.2,
        "WarningThreshold": 3.8,
        "CriticalThreshold":3.4,
        "UnitType":   "score_1_to_5",
    },
    {
        "KPIName":    "Protection Plan Renewal Rate",
        "KPICode":    "PP_RNW_RATE",
        "Domain":     "Retention",
        "Owner":      "christopher.dingle@enercare.ca",
        "Formula":    (
            'DIVIDE('
            'CALCULATE(COUNTROWS(fct_pp_contract_renewals), fct_pp_contract_renewals[renewal_status_code] = "renewed"), '
            'CALCULATE(COUNTROWS(fct_pp_contract_renewals), fct_pp_contract_renewals[renewal_status_code] IN {"renewed","lapsed","cancelled"}))'
        ),
        "Description": (
            "Percentage of expiring Protection Plan contracts successfully renewed within the renewal window "
            "(30 days before to 15 days after contract end date). Applies to HVAC_PLAN and WH_RENTAL_PLAN. "
            "Excludes mid-term cancellations. Target: 82%."
        ),
        "TargetValue":      0.82,
        "WarningThreshold": 0.75,
        "CriticalThreshold":0.68,
        "UnitType":   "percentage",
    },
    {
        "KPIName":    "Average Handle Time",
        "KPICode":    "AHT",
        "Domain":     "Call Center",
        "Owner":      "ranbir.singh@enercare.ca",
        "Formula":    "AVERAGEX(fct_cc_interactions, fct_cc_interactions[handle_time_sec] + fct_cc_interactions[hold_time_sec])",
        "Description": (
            "Average seconds of agent engagement per interaction: talk time + hold time + after-call wrap-up. "
            "Measured per queue type. Targets: billing=420s, emergency=300s, PP_renewal=480s."
        ),
        "TargetValue":      420.0,
        "WarningThreshold": 480.0,
        "CriticalThreshold":540.0,
        "UnitType":   "seconds",
    },
    {
        "KPIName":    "SLA Breach Rate",
        "KPICode":    "SLA_BRCH_RATE",
        "Domain":     "Field Operations",
        "Owner":      "ranbir.singh@enercare.ca",
        "Formula":    (
            'DIVIDE('
            'CALCULATE(COUNTROWS(fct_sv_service_visits), fct_sv_service_visits[sla_breach_flg] = "Y"), '
            'COUNTROWS(fct_sv_service_visits))'
        ),
        "Description": (
            "Percentage of field service visits where the technician did not arrive within the committed window. "
            "SLA windows: emergency=4h, maintenance=scheduled date, repair=next business day. "
            "Measured per equipment type. Target: 5%."
        ),
        "TargetValue":      0.05,
        "WarningThreshold": 0.10,
        "CriticalThreshold":0.15,
        "UnitType":   "percentage",
    },
]

certified_date_obj = date.fromisoformat(CERTIFIED_DATE)

rows_set_b = []
for k in cc_kpi_defs:
    rows_set_b.append(Row(
        KPIName          = k["KPIName"],
        Formula          = k["Formula"],
        Description      = k["Description"],
        Domain           = k["Domain"],
        Owner            = k["Owner"],
        IsDraft          = 0,
        KPICode          = k["KPICode"],
        IsCertified      = 1,
        Version          = 1,
        PreviousFormula  = None,
        CertifiedBy      = CERTIFIED_BY,
        CertifiedDate    = certified_date_obj,
        TargetValue      = k["TargetValue"],
        WarningThreshold = k["WarningThreshold"],
        CriticalThreshold= k["CriticalThreshold"],
        UnitType         = k["UnitType"],
    ))

df_set_b = spark.createDataFrame(rows_set_b)

if DEMO_MODE:
    print(f"[DEMO_MODE] Set B — {len(rows_set_b)} certified call center KPIs (IsCertified=1):\n")
    df_set_b.select("KPICode", "KPIName", "Domain", "IsCertified",
                    "TargetValue", "UnitType", "CertifiedBy").show(truncate=False)
else:
    df_set_b.write.format("delta").mode("append").option("mergeSchema", "true") \
            .saveAsTable(f"{METADATA_LAKEHOUSE}.kpi_metadata")
    print(f"kpi_metadata seeded: {len(rows_set_b)} certified call center KPIs")


# CELL 8 — Seed ai_metadata: verified answers for FCR, CSAT, PP_RNW_RATE
# G1-4, G4: pre-approved verified answers for Copilot "Prep Data for AI"
# ──────────────────────────────────────────────────────────────────────────

verified_answers = [
    # (kpi_code, trigger_phrase, response_text)
    ("FCR", "what is our FCR",
     "FCR (First Contact Resolution) measures whether a customer's issue was resolved "
     "in a single interaction without a callback within 5 business days. Target: 78%. "
     "FCR is calculated per interaction — not per customer. Outbound welcome calls are excluded."),
    ("FCR", "first contact resolution",
     "First Contact Resolution Rate is the percentage of inbound interactions that did not "
     "generate a follow-up contact within 5 business days. It is our primary call center efficiency KPI."),
    ("FCR", "call back rate",
     "Callback rate is the inverse of FCR. If FCR is 78%, approximately 22% of customers "
     "contacted us again within 5 days about the same issue."),
    ("FCR", "how often do customers call back",
     "FCR tracks this. An FCR below 72% (warning threshold) means more than 28% of customers "
     "needed a follow-up contact within 5 business days."),

    ("CSAT", "what is our CSAT",
     "CSAT (Customer Satisfaction Score) is a post-call IVR survey score from 1 to 5 "
     "(5 = very satisfied). Only ~22% of customers complete the survey. Target: 4.2. "
     "A NULL csat_score means the customer did not respond — do not treat it as a low score."),
    ("CSAT", "customer satisfaction",
     "Customer satisfaction is measured via post-call IVR survey on a 1–5 scale. "
     "CSAT below 3.5 on a queue indicates a systemic issue, not individual agent performance."),
    ("CSAT", "how happy are customers",
     "Use the CSAT measure, which averages post-call survey responses. "
     "Note: only ~22% of customers respond, so filter for non-null csat_score for accurate averages."),
    ("CSAT", "satisfaction score",
     "CSAT averages the IVR survey score across interactions. Filter to completed surveys "
     "(csat_score IS NOT NULL) when calculating averages. Target: 4.2 out of 5."),

    ("PP_RNW_RATE", "PP renewal rate",
     "PP Renewal Rate measures how many customers renew their HVAC or water heater Protection Plans. "
     "This is the primary retention KPI. Renewal window: 30 days before to 15 days after contract end. "
     "Target: 82%. Excludes mid-term cancellations."),
    ("PP_RNW_RATE", "protection plan renewal",
     "Protection Plan Renewal Rate = renewed contracts / (renewed + lapsed + cancelled) contracts "
     "that reached expiry. Applies to HVAC_PLAN and WH_RENTAL_PLAN product codes only."),
    ("PP_RNW_RATE", "how many customers renewed",
     "Use PP_RNW_RATE to track renewal performance. Renewals can happen via inbound call, "
     "outbound retention call, online portal, or direct mail. Target: 82% renewal rate."),
    ("PP_RNW_RATE", "renewal rate",
     "PP Renewal Rate is 82% target. Customers calling the billing queue before renewal date "
     "and not renewing often signals billing confusion — cross-reference with AHT on billing queue."),
    ("PP_RNW_RATE", "contract renewal",
     "Contract renewal performance is tracked by PP_RNW_RATE. The renewal window is "
     "30 days before to 15 days after the contract end date."),
]

record_id = 1
rows_va = []
for kpi_code, trigger, response in verified_answers:
    rows_va.append(Row(
        RecordID      = record_id,
        ModelName     = MODEL_NAME,
        RecordType    = "verified_answer",
        TriggerText   = trigger,
        ResponseText  = response,
        LinkedKPICode = kpi_code,
        IsDraft       = 0,
        CreatedDate   = date.fromisoformat(CERTIFIED_DATE),
    ))
    record_id += 1

df_va = spark.createDataFrame(rows_va)

if DEMO_MODE:
    print(f"[DEMO_MODE] Verified answers — {len(rows_va)} rows across FCR, CSAT, PP_RNW_RATE:\n")
    df_va.select("RecordID", "LinkedKPICode", "TriggerText").show(truncate=60)
else:
    df_va.write.format("delta").mode("append").option("mergeSchema", "true") \
         .saveAsTable(f"{METADATA_LAKEHOUSE}.ai_metadata")
    print(f"ai_metadata seeded: {len(rows_va)} verified answers")


# CELL 9 — Seed ai_metadata: AI instruction rows
# G1-4, G4: model-level AI instructions for Copilot semantic understanding
# ──────────────────────────────────────────────────────────────────────────

ai_instructions = [
    (
        "Business Context",
        "Enercare context",
        "Enercare is a Canadian home services company providing HVAC maintenance, water heater "
        "rentals, Protection Plans (PP), and Ecobee smart thermostat installation in Ontario. "
        "Billing systems: ZUORA (recurring), NS (NetSuite), CLARIFY (CRM/field service). "
        "PP = Protection Plan throughout this system. MRR = Monthly Recurring Revenue. "
        "The contact center handles billing, PP renewal, HVAC service, emergency, new sales, and Ecobee support queues."
    ),
    (
        "Critical Terminology",
        "Enercare terminology",
        "FCR = First Contact Resolution (resolved without callback in 5 business days). "
        "CSAT = Customer Satisfaction Score (1–5 IVR survey, ~22% response rate). "
        "AHT = Average Handle Time (talk + hold + wrap seconds). "
        "PP_RNW_RATE = Protection Plan Renewal Rate (target 82%). "
        "SLA Breach = field technician missed committed service window. "
        "WH = Water Heater. HVAC = Heating Ventilation Air Conditioning. "
        "MUR = Multi-Unit Residential. FSA = Forward Sortation Area (first 3 chars of postal code)."
    ),
    (
        "KPI Definitions",
        "certified KPI reference",
        "Five certified call center KPIs: "
        "FCR target 78% (warning <72%, critical <65%); "
        "CSAT target 4.2/5 (warning <3.8, critical <3.4); "
        "PP_RNW_RATE target 82% (warning <75%, critical <68%); "
        "AHT target 420s billing queue (warning >480s, critical >540s); "
        "SLA_BRCH_RATE target 5% (warning >10%, critical >15%). "
        "Only IsCertified=1 KPIs have been approved by Christopher Dingle. "
        "Do not present non-certified measures as authoritative business KPIs."
    ),
]

rows_instr = []
for title, trigger, content in ai_instructions:
    rows_instr.append(Row(
        RecordID      = record_id,
        ModelName     = MODEL_NAME,
        RecordType    = "ai_instruction",
        TriggerText   = trigger,
        ResponseText  = content,
        LinkedKPICode = None,
        IsDraft       = 0,
        CreatedDate   = date.fromisoformat(CERTIFIED_DATE),
    ))
    record_id += 1

df_instr = spark.createDataFrame(rows_instr)

if DEMO_MODE:
    print(f"[DEMO_MODE] AI instruction rows — {len(rows_instr)} rows:\n")
    df_instr.select("RecordID", "RecordType", "TriggerText").show(truncate=60)
else:
    df_instr.write.format("delta").mode("append").option("mergeSchema", "true") \
            .saveAsTable(f"{METADATA_LAKEHOUSE}.ai_metadata")
    print(f"ai_metadata seeded: {len(rows_instr)} AI instruction rows")


# CELL 10 — Update vw_business_metadata_current
# Extends the existing view to include ai_metadata with a SourceTable discriminator
# ──────────────────────────────────────────────────────────────────────────

sql_view = f"""
CREATE OR REPLACE VIEW {METADATA_LAKEHOUSE}.vw_business_metadata_current AS

-- Asset-level metadata
SELECT
    'asset'          AS RecordCategory,
    'asset_metadata' AS SourceTable,
    AssetName        AS ObjectKey,
    Description,
    Owner,
    Steward,
    Domain,
    Sensitivity,
    IsDraft,
    DefinitionHash,
    CAST(NULL AS STRING) AS KPICode,
    CAST(NULL AS INT)    AS IsCertified,
    CAST(NULL AS STRING) AS Formula,
    CAST(NULL AS STRING) AS TriggerText,
    CAST(NULL AS STRING) AS ResponseText
FROM {METADATA_LAKEHOUSE}.asset_metadata

UNION ALL

-- Column-level metadata
SELECT
    'column'           AS RecordCategory,
    'column_metadata'  AS SourceTable,
    CONCAT(AssetName, '.', ColumnName) AS ObjectKey,
    Description,
    CAST(NULL AS STRING) AS Owner,
    CAST(NULL AS STRING) AS Steward,
    CAST(NULL AS STRING) AS Domain,
    CAST(NULL AS STRING) AS Sensitivity,
    IsDraft,
    CAST(NULL AS STRING) AS DefinitionHash,
    CAST(NULL AS STRING) AS KPICode,
    CAST(NULL AS INT)    AS IsCertified,
    CAST(NULL AS STRING) AS Formula,
    ColumnName           AS TriggerText,
    DataType             AS ResponseText
FROM {METADATA_LAKEHOUSE}.column_metadata

UNION ALL

-- KPI definitions
SELECT
    'kpi'           AS RecordCategory,
    'kpi_metadata'  AS SourceTable,
    KPICode         AS ObjectKey,
    Description,
    Owner,
    CAST(NULL AS STRING) AS Steward,
    Domain,
    CAST(NULL AS STRING) AS Sensitivity,
    IsDraft,
    CAST(NULL AS STRING) AS DefinitionHash,
    KPICode,
    IsCertified,
    Formula,
    CAST(NULL AS STRING) AS TriggerText,
    CAST(NULL AS STRING) AS ResponseText
FROM {METADATA_LAKEHOUSE}.kpi_metadata

UNION ALL

-- AI metadata: verified answers, instructions, term mappings
SELECT
    RecordType          AS RecordCategory,
    'ai_metadata'       AS SourceTable,
    COALESCE(LinkedKPICode, ModelName) AS ObjectKey,
    ResponseText        AS Description,
    CAST(NULL AS STRING) AS Owner,
    CAST(NULL AS STRING) AS Steward,
    CAST(NULL AS STRING) AS Domain,
    CAST(NULL AS STRING) AS Sensitivity,
    IsDraft,
    CAST(NULL AS STRING) AS DefinitionHash,
    LinkedKPICode        AS KPICode,
    CAST(NULL AS INT)    AS IsCertified,
    CAST(NULL AS STRING) AS Formula,
    TriggerText,
    ResponseText
FROM {METADATA_LAKEHOUSE}.ai_metadata
""".strip()

if DEMO_MODE:
    print("[DEMO_MODE] Would execute vw_business_metadata_current replacement:\n")
    print(sql_view[:800], "\n  ... [truncated — full SQL in DEMO_MODE=False run]")
else:
    spark.sql(sql_view)
    row_counts = spark.sql(
        f"SELECT SourceTable, COUNT(*) AS rows FROM {METADATA_LAKEHOUSE}.vw_business_metadata_current "
        f"GROUP BY SourceTable ORDER BY SourceTable"
    )
    print("vw_business_metadata_current updated:")
    row_counts.show()


# CELL 11 — Completion summary
# ──────────────────────────────────────────────────────────────────────────

total_va    = len(rows_va)
total_instr = len(rows_instr)

if DEMO_MODE:
    print("""
lh_metadata schema extension — DEMO_MODE summary (no changes written):
  kpi_metadata:    +10 columns queued (ALTER TABLE)
  ai_metadata:     CREATE TABLE queued
  data_owners:     CREATE TABLE queued
  lineage_edges:   CREATE TABLE queued
  kpi_metadata:    17 KPIs queued (12 existing measures + 5 call center)
  ai_metadata:     {va} verified answers + {instr} AI instructions queued

Set DEMO_MODE = False to execute against lh_metadata.
Gaps addressed: G1-3, G1-4, G1-5, G1-7, G2-1, G2-2
""".format(va=total_va, instr=total_instr))
else:
    kpi_total = spark.sql(
        f"SELECT COUNT(*) AS n FROM {METADATA_LAKEHOUSE}.kpi_metadata"
    ).first()["n"]
    ai_total  = spark.sql(
        f"SELECT RecordType, COUNT(*) AS n FROM {METADATA_LAKEHOUSE}.ai_metadata GROUP BY RecordType"
    )
    print(f"""
lh_metadata schema extension complete:
  kpi_metadata:    10 new columns added
  ai_metadata:     created and seeded
  data_owners:     created
  lineage_edges:   created
  kpi_metadata:    {kpi_total} total KPIs ({len(existing_measures)} existing + {len(cc_kpi_defs)} call center)
  ai_metadata:     {total_va} verified answers + {total_instr} AI instructions
""")
    ai_total.show()
    print("Gaps closed: G1-3 ✓  G1-4 ✓  G1-5 ✓  G1-7 ✓  G2-1 ✓  G2-2 ✓")
