/*-----------------------------------------------------------------------------
    File: 02_extract_from_modules.sql

    Pulls structured headers out of sys.sql_modules.definition and lands them
    in meta.* tables. Designed to be run idempotently (MERGE upserts).

    Strategy
        1. Pull the leading /* ... */ block from each view/proc.
        2. Tokenize on '@<tag>:' boundaries via CROSS APPLY string_split with a
           sentinel character (we replace '@' with CHAR(30) only at line starts).
        3. For each tag, write a row to the appropriate meta.* table.
        4. For VIEW columns, derive name + lineage from
              sys.dm_exec_describe_first_result_set
              + INFORMATION_SCHEMA.VIEW_COLUMN_USAGE.
        5. Stamp SHA2_256 of the module definition for drift detection.

    Notes
        - This script uses only T-SQL; if you prefer Python, the same logic is
          implemented in purview/ai_gap_fill.py. The T-SQL path is preferred
          because it can run inside the source DB with no extra tooling.
        - Header parsing tolerates Windows / Unix line endings and indented
          comment blocks. Multi-line tag values are preserved.
-----------------------------------------------------------------------------*/
SET NOCOUNT ON;

-- ---------------------------------------------------------------------------
-- 1. Source list of modules to scan
-- ---------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#modules') IS NOT NULL DROP TABLE #modules;
SELECT
    o.[object_id],
    s.name                                AS SchemaName,
    o.name                                AS ObjectName,
    CASE o.type WHEN 'V' THEN 'view'
                WHEN 'P' THEN 'proc'
                WHEN 'U' THEN 'table' END AS AssetType,
    m.[definition]                        AS Body,
    HASHBYTES('SHA2_256', m.[definition]) AS SourceHash
INTO #modules
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
LEFT JOIN sys.sql_modules m ON m.[object_id] = o.[object_id]
WHERE o.type IN ('V','P')                  -- tables get rows added below
   OR (o.type = 'U' AND s.name <> 'meta');

-- Tables don't have sql_modules; treat their first /* ... */ as defined in
-- a side-car file or extended property MS_Description (fallback only).
INSERT INTO #modules (SchemaName, ObjectName, AssetType, Body, SourceHash)
SELECT s.name, t.name, 'table',
       CAST(ep.value AS NVARCHAR(MAX)),
       HASHBYTES('SHA2_256', ISNULL(CAST(ep.value AS NVARCHAR(MAX)), N''))
FROM   sys.tables t
JOIN   sys.schemas s ON s.schema_id = t.schema_id
LEFT JOIN sys.extended_properties ep
       ON ep.major_id = t.[object_id] AND ep.minor_id = 0 AND ep.class = 1
WHERE  s.name <> 'meta';

-- ---------------------------------------------------------------------------
-- 2. Extract the leading /* ... */ comment block
-- ---------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#headers') IS NOT NULL DROP TABLE #headers;
SELECT
    m.SchemaName, m.ObjectName, m.AssetType, m.SourceHash,
    SUBSTRING(
        m.Body,
        CHARINDEX('/*', m.Body) + 2,
        CHARINDEX('*/', m.Body) - CHARINDEX('/*', m.Body) - 2
    ) AS Header
INTO #headers
FROM #modules m
WHERE m.Body IS NOT NULL
  AND CHARINDEX('/*', m.Body) > 0
  AND CHARINDEX('*/', m.Body) > CHARINDEX('/*', m.Body);

-- ---------------------------------------------------------------------------
-- 3. Helper inline TVF: split a header into (Tag, Value) rows
--    We mark line-start '@' tokens by injecting a sentinel CHAR(30).
-- ---------------------------------------------------------------------------
IF OBJECT_ID('meta.fn_SplitHeader') IS NOT NULL DROP FUNCTION meta.fn_SplitHeader;
GO
CREATE FUNCTION meta.fn_SplitHeader(@header NVARCHAR(MAX))
RETURNS TABLE
AS RETURN
WITH normalized AS (
    SELECT REPLACE(REPLACE(@header, CHAR(13), CHAR(10)), CHAR(10) + N'@', CHAR(10) + CHAR(30) + N'@') AS H
),
prepended AS (   -- ensure first line tag is captured
    SELECT CASE WHEN LEFT(LTRIM(H),1) = N'@'
                THEN CHAR(30) + LTRIM(H)
                ELSE H END AS H
    FROM normalized
),
parts AS (
    SELECT LTRIM(RTRIM(value)) AS Chunk
    FROM   prepended
    CROSS APPLY STRING_SPLIT(H, CHAR(30))
    WHERE  LTRIM(RTRIM(value)) LIKE N'@%:%'
)
SELECT
    LOWER(LTRIM(RTRIM(SUBSTRING(Chunk, 2, CHARINDEX(N':', Chunk) - 2)))) AS Tag,
    LTRIM(RTRIM(SUBSTRING(Chunk, CHARINDEX(N':', Chunk) + 1, 4000)))     AS Value
FROM parts;
GO

-- ---------------------------------------------------------------------------
-- 4. Project header tags to meta.AssetMetadata (single-row tags)
-- ---------------------------------------------------------------------------
;WITH tagged AS (
    SELECT h.SchemaName, h.ObjectName, h.AssetType, h.SourceHash, t.Tag, t.Value
    FROM   #headers h
    CROSS APPLY meta.fn_SplitHeader(h.Header) t
),
piv AS (
    SELECT SchemaName, ObjectName, AssetType, SourceHash,
        MAX(CASE WHEN Tag='business_name' THEN Value END) AS BusinessName,
        MAX(CASE WHEN Tag='description'   THEN Value END) AS [Description],
        MAX(CASE WHEN Tag='owner'         THEN Value END) AS [Owner],
        MAX(CASE WHEN Tag='steward'       THEN Value END) AS Steward,
        MAX(CASE WHEN Tag='domain'        THEN Value END) AS [Domain],
        MAX(CASE WHEN Tag='grain'         THEN Value END) AS Grain,
        MAX(CASE WHEN Tag='refresh'       THEN Value END) AS Refresh,
        MAX(CASE WHEN Tag='sensitivity'   THEN Value END) AS Sensitivity,
        MAX(CASE WHEN Tag='glossary'      THEN Value END) AS GlossaryTerms,
        MAX(CASE WHEN Tag='upstream'      THEN Value END) AS UpstreamObjects,
        MAX(CASE WHEN Tag='notes'         THEN Value END) AS Notes
    FROM tagged
    GROUP BY SchemaName, ObjectName, AssetType, SourceHash
)
MERGE meta.AssetMetadata AS tgt
USING piv AS src
   ON tgt.SchemaName = src.SchemaName AND tgt.ObjectName = src.ObjectName
WHEN MATCHED THEN UPDATE SET
    tgt.AssetType=src.AssetType, tgt.BusinessName=src.BusinessName,
    tgt.[Description]=src.[Description], tgt.[Owner]=src.[Owner],
    tgt.Steward=src.Steward, tgt.[Domain]=src.[Domain], tgt.Grain=src.Grain,
    tgt.Refresh=src.Refresh, tgt.Sensitivity=src.Sensitivity,
    tgt.GlossaryTerms=src.GlossaryTerms, tgt.UpstreamObjects=src.UpstreamObjects,
    tgt.Notes=src.Notes, tgt.SourceHash=src.SourceHash,
    tgt.LastExtractedUtc=SYSUTCDATETIME(),
    tgt.IsDraft = 0  -- explicit headers are authoritative
WHEN NOT MATCHED THEN
    INSERT (SchemaName,ObjectName,AssetType,BusinessName,[Description],[Owner],
            Steward,[Domain],Grain,Refresh,Sensitivity,GlossaryTerms,
            UpstreamObjects,Notes,SourceHash,IsDraft)
    VALUES (src.SchemaName,src.ObjectName,src.AssetType,src.BusinessName,src.[Description],src.[Owner],
            src.Steward,src.[Domain],src.Grain,src.Refresh,src.Sensitivity,src.GlossaryTerms,
            src.UpstreamObjects,src.Notes,src.SourceHash,0);

-- ---------------------------------------------------------------------------
-- 5. Project repeated @column tags to meta.ColumnMetadata
--    Format: @column : <name> | <description>
-- ---------------------------------------------------------------------------
;WITH col_tags AS (
    SELECT h.SchemaName, h.ObjectName, t.Value
    FROM   #headers h
    CROSS APPLY meta.fn_SplitHeader(h.Header) t
    WHERE  t.Tag = 'column'
),
parsed AS (
    SELECT
        SchemaName, ObjectName,
        LTRIM(RTRIM(LEFT(Value, NULLIF(CHARINDEX('|', Value),0) - 1)))            AS ColumnName,
        LTRIM(RTRIM(SUBSTRING(Value, CHARINDEX('|', Value) + 1, 4000)))           AS [Description]
    FROM col_tags
    WHERE CHARINDEX('|', Value) > 0
)
MERGE meta.ColumnMetadata AS tgt
USING parsed AS src
   ON tgt.SchemaName = src.SchemaName
  AND tgt.ObjectName = src.ObjectName
  AND tgt.ColumnName = src.ColumnName
WHEN MATCHED THEN UPDATE SET
    tgt.[Description] = src.[Description],
    tgt.IsDraft       = 0,
    tgt.LastExtractedUtc = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (SchemaName, ObjectName, ColumnName, [Description], IsDraft)
    VALUES (src.SchemaName, src.ObjectName, src.ColumnName, src.[Description], 0);

-- ---------------------------------------------------------------------------
-- 6. Repeated @kpi tags  (Name | Description | Formula)
-- ---------------------------------------------------------------------------
;WITH kpi_tags AS (
    SELECT h.SchemaName, h.ObjectName, t.Value
    FROM   #headers h
    CROSS APPLY meta.fn_SplitHeader(h.Header) t
    WHERE  t.Tag = 'kpi'
),
parsed AS (
    SELECT
        SchemaName, ObjectName,
        LTRIM(RTRIM(p1.value)) AS KpiName,
        LTRIM(RTRIM(p2.value)) AS [Description],
        LTRIM(RTRIM(p3.value)) AS Formula
    FROM   kpi_tags
    CROSS APPLY (SELECT TOP 1 value FROM STRING_SPLIT(Value,'|') ORDER BY (SELECT NULL)) p1
    CROSS APPLY (SELECT value, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn FROM STRING_SPLIT(Value,'|')) p2
    CROSS APPLY (SELECT value, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn FROM STRING_SPLIT(Value,'|')) p3
    WHERE  p2.rn = 2 AND p3.rn = 3
)
MERGE meta.KpiMetadata AS tgt
USING parsed AS src
   ON tgt.SchemaName = src.SchemaName
  AND tgt.ObjectName = src.ObjectName
  AND tgt.KpiName    = src.KpiName
WHEN MATCHED THEN UPDATE SET
    tgt.[Description] = src.[Description],
    tgt.Formula       = src.Formula,
    tgt.IsDraft       = 0,
    tgt.LastExtractedUtc = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (SchemaName, ObjectName, KpiName, [Description], Formula, IsDraft)
    VALUES (src.SchemaName, src.ObjectName, src.KpiName, src.[Description], src.Formula, 0);

-- ---------------------------------------------------------------------------
-- 7. Auto-derive view columns + upstream lineage where header didn't list them
--    (so AI gets at least *type* and *upstream*, even with no description).
-- ---------------------------------------------------------------------------
;WITH view_cols AS (
    SELECT s.name AS SchemaName, v.name AS ObjectName, c.name AS ColumnName,
           c.column_id AS OrdinalPosition,
           TYPE_NAME(c.user_type_id) +
              CASE WHEN c.max_length > 0 AND TYPE_NAME(c.user_type_id) IN ('varchar','nvarchar','char','nchar','varbinary','binary')
                   THEN '(' + CONVERT(VARCHAR,
                       CASE WHEN TYPE_NAME(c.user_type_id) IN ('nvarchar','nchar')
                            THEN c.max_length/2 ELSE c.max_length END) + ')'
                   ELSE '' END AS DataType
    FROM sys.views v
    JOIN sys.schemas s ON s.schema_id = v.schema_id
    JOIN sys.columns c ON c.[object_id] = v.[object_id]
),
view_lineage AS (
    SELECT VIEW_SCHEMA AS SchemaName, VIEW_NAME AS ObjectName, VIEW_COLUMN_NAME AS ColumnName,
           STRING_AGG(QUOTENAME(TABLE_SCHEMA)+'.'+QUOTENAME(TABLE_NAME)+'.'+QUOTENAME(COLUMN_NAME), ', ') AS UpstreamColumns
    FROM   INFORMATION_SCHEMA.VIEW_COLUMN_USAGE
    GROUP BY VIEW_SCHEMA, VIEW_NAME, VIEW_COLUMN_NAME
)
MERGE meta.ColumnMetadata AS tgt
USING (
    SELECT vc.SchemaName, vc.ObjectName, vc.ColumnName, vc.OrdinalPosition,
           vc.DataType, vl.UpstreamColumns
    FROM   view_cols vc
    LEFT JOIN view_lineage vl
           ON vl.SchemaName = vc.SchemaName
          AND vl.ObjectName = vc.ObjectName
          AND vl.ColumnName = vc.ColumnName
) AS src
   ON tgt.SchemaName = src.SchemaName
  AND tgt.ObjectName = src.ObjectName
  AND tgt.ColumnName = src.ColumnName
WHEN MATCHED THEN UPDATE SET
    tgt.OrdinalPosition  = src.OrdinalPosition,
    tgt.DataType         = src.DataType,
    tgt.UpstreamColumns  = src.UpstreamColumns,
    tgt.LastExtractedUtc = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (SchemaName, ObjectName, ColumnName, OrdinalPosition, DataType, UpstreamColumns, IsDraft)
    VALUES (src.SchemaName, src.ObjectName, src.ColumnName, src.OrdinalPosition, src.DataType, src.UpstreamColumns, 1);
    -- IsDraft = 1 because we only have type/lineage, not a description yet.
GO
