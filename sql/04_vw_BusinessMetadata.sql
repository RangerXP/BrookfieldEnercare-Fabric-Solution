/*-----------------------------------------------------------------------------
    File: 04_vw_BusinessMetadata.sql
    Single read endpoint consumed by Fabric notebooks, Purview push, and any
    AI agent. Exposes everything in one wide row per (asset, column).
-----------------------------------------------------------------------------*/
CREATE OR ALTER VIEW meta.vw_BusinessMetadata
AS
SELECT
    @@SERVERNAME              AS ServerName,
    DB_NAME()                 AS DatabaseName,
    a.SchemaName,
    a.ObjectName,
    a.AssetType,
    a.BusinessName,
    a.[Description]           AS AssetDescription,
    a.[Owner],
    a.Steward,
    a.[Domain],
    a.Grain,
    a.Refresh,
    a.Sensitivity             AS AssetSensitivity,
    a.GlossaryTerms           AS AssetGlossaryTerms,
    a.UpstreamObjects,

    cm.ColumnName,
    cm.OrdinalPosition,
    cm.DataType,
    cm.[Description]          AS ColumnDescription,
    cm.UpstreamColumns,
    cm.GlossaryTerms          AS ColumnGlossaryTerms,
    cm.Sensitivity            AS ColumnSensitivity,

    -- Purview-style qualified name for direct join in the catalog push script
    CONCAT('mssql://', @@SERVERNAME, '/', DB_NAME(), '/', a.SchemaName, '/',
           a.ObjectName,
           CASE WHEN cm.ColumnName IS NULL THEN '' ELSE '#' + cm.ColumnName END) AS PurviewQualifiedName,

    a.IsDraft                 AS AssetIsDraft,
    cm.IsDraft                AS ColumnIsDraft,
    a.LastExtractedUtc
FROM       meta.AssetMetadata  a
LEFT JOIN  meta.ColumnMetadata cm
       ON  cm.SchemaName = a.SchemaName
      AND  cm.ObjectName = a.ObjectName;
GO
