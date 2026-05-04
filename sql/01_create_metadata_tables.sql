/*-----------------------------------------------------------------------------
    File: 01_create_metadata_tables.sql
    The canonical metadata store. Everything downstream (extended_properties,
    Fabric Lakehouse, Warehouse, Semantic Model, Purview) is projected from here.
-----------------------------------------------------------------------------*/
IF SCHEMA_ID('meta') IS NULL EXEC('CREATE SCHEMA meta');
GO

-- ---- Asset-level metadata (table / view / proc) ----------------------------
IF OBJECT_ID('meta.AssetMetadata') IS NULL
CREATE TABLE meta.AssetMetadata (
    AssetMetadataId   BIGINT IDENTITY(1,1) PRIMARY KEY,
    SchemaName        SYSNAME       NOT NULL,
    ObjectName        SYSNAME       NOT NULL,
    AssetType         VARCHAR(16)   NOT NULL,            -- table|view|proc
    BusinessName      NVARCHAR(200) NULL,
    [Description]     NVARCHAR(MAX) NULL,
    [Owner]           NVARCHAR(200) NULL,
    Steward           NVARCHAR(200) NULL,
    [Domain]          NVARCHAR(100) NULL,
    Grain             NVARCHAR(400) NULL,
    Refresh           NVARCHAR(100) NULL,
    Sensitivity       NVARCHAR(50)  NULL,
    GlossaryTerms     NVARCHAR(MAX) NULL,                -- CSV
    UpstreamObjects   NVARCHAR(MAX) NULL,                -- CSV (parsed or declared)
    Notes             NVARCHAR(MAX) NULL,
    SourceHash        BINARY(32)    NULL,                -- SHA2_256(sys.sql_modules.definition)
    IsDraft           BIT           NOT NULL DEFAULT 0,  -- AI gap-fills land here as 1
    LastExtractedUtc  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_AssetMetadata UNIQUE (SchemaName, ObjectName)
);
GO

-- ---- Column-level metadata --------------------------------------------------
IF OBJECT_ID('meta.ColumnMetadata') IS NULL
CREATE TABLE meta.ColumnMetadata (
    ColumnMetadataId  BIGINT IDENTITY(1,1) PRIMARY KEY,
    SchemaName        SYSNAME       NOT NULL,
    ObjectName        SYSNAME       NOT NULL,
    ColumnName        SYSNAME       NOT NULL,
    OrdinalPosition   INT           NULL,
    DataType          NVARCHAR(128) NULL,
    [Description]     NVARCHAR(MAX) NULL,
    UpstreamColumns   NVARCHAR(MAX) NULL,    -- CSV "schema.table.column"
    GlossaryTerms     NVARCHAR(MAX) NULL,
    Sensitivity       NVARCHAR(50)  NULL,
    IsDraft           BIT           NOT NULL DEFAULT 0,
    LastExtractedUtc  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_ColumnMetadata UNIQUE (SchemaName, ObjectName, ColumnName)
);
GO

-- ---- KPI / measure metadata (often defined in stored procs) ----------------
IF OBJECT_ID('meta.KpiMetadata') IS NULL
CREATE TABLE meta.KpiMetadata (
    KpiMetadataId     BIGINT IDENTITY(1,1) PRIMARY KEY,
    SchemaName        SYSNAME       NOT NULL,
    ObjectName        SYSNAME       NOT NULL,
    KpiName           NVARCHAR(200) NOT NULL,
    [Description]     NVARCHAR(MAX) NULL,
    Formula           NVARCHAR(MAX) NULL,
    GlossaryTerms     NVARCHAR(MAX) NULL,
    IsDraft           BIT           NOT NULL DEFAULT 0,
    LastExtractedUtc  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_KpiMetadata UNIQUE (SchemaName, ObjectName, KpiName)
);
GO

-- ---- Stored proc parameters (optional but useful for AI agents) ------------
IF OBJECT_ID('meta.ParameterMetadata') IS NULL
CREATE TABLE meta.ParameterMetadata (
    ParameterMetadataId BIGINT IDENTITY(1,1) PRIMARY KEY,
    SchemaName        SYSNAME       NOT NULL,
    ObjectName        SYSNAME       NOT NULL,
    Direction         VARCHAR(8)    NOT NULL,    -- input|output
    ParameterName     SYSNAME       NOT NULL,
    [Description]     NVARCHAR(MAX) NULL,
    DataType          NVARCHAR(128) NULL,
    IsDraft           BIT           NOT NULL DEFAULT 0,
    CONSTRAINT UQ_ParameterMetadata UNIQUE (SchemaName, ObjectName, Direction, ParameterName)
);
GO
