# ---------------------------------------------------------------------------
# demo/fabric/nb_05b_test_sql_connectivity.py
# Python source mirror of pbi/nb_05b_test_sql_connectivity.Notebook/notebook-content.py
# Purpose: Minimal JDBC smoke test for sqlserver-sk2 over the Fabric managed
#          private endpoint created on the Enercare workspace.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# CELL 1 — Config
# ---------------------------------------------------------------------------

# DEMO_MODE = True  -> dry-run (prints the JDBC plan, no connection attempt)
# DEMO_MODE = False -> live (acquires an Entra token and runs a small query)

DEMO_MODE                  = True
WORKSPACE_ID               = "795ce5db-7ea0-4a7c-ba64-e27c9fb568f4"
SERVER_NAME                = "sqlserver-sk2.database.windows.net"
DATABASE_NAME              = "master"
SQL_PORT                   = 1433
SQL_LOGIN_TIMEOUT_SECONDS  = 30
TEST_QUERY                 = "SELECT TOP 1 name AS database_name FROM sys.databases ORDER BY name"

print(f"nb_05b_test_sql_connectivity  |  DEMO_MODE={DEMO_MODE}")
print(f"Workspace: {WORKSPACE_ID}")
print(f"Target: {SERVER_NAME}:{SQL_PORT} / {DATABASE_NAME}")


# ---------------------------------------------------------------------------
# CELL 2 — Build JDBC config and acquire token
# ---------------------------------------------------------------------------

JDBC_URL = (
    f"jdbc:sqlserver://{SERVER_NAME}:{SQL_PORT};"
    f"database={DATABASE_NAME};"
    "encrypt=true;"
    "trustServerCertificate=false;"
    "hostNameInCertificate=*.database.windows.net;"
    f"loginTimeout={SQL_LOGIN_TIMEOUT_SECONDS};"
)


def get_sql_access_token():
    scopes = [
        "https://database.windows.net/",
        "https://database.windows.net",
    ]
    last_error = None
    for scope in scopes:
        try:
            return mssparkutils.credentials.getToken(scope)
        except Exception as exc:
            last_error = exc
    raise last_error


print("JDBC URL prepared.")
print(f"Smoke-test query: {TEST_QUERY}")

if DEMO_MODE:
    print("[DRY RUN] Skipping token acquisition and JDBC call.")
    print("[DRY RUN] Switch DEMO_MODE=False to run the query through the workspace managed private endpoint.")
else:
    sql_access_token = get_sql_access_token()
    print("Acquired Microsoft Entra access token for Azure SQL.")


# ---------------------------------------------------------------------------
# CELL 3 — Execute minimal JDBC connectivity test
# ---------------------------------------------------------------------------

if DEMO_MODE:
    print("[DRY RUN] No JDBC connection attempted.")
else:
    test_df = (
        spark.read.format("jdbc")
        .option("url", JDBC_URL)
        .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver")
        .option("query", TEST_QUERY)
        .option("accessToken", sql_access_token)
        .load()
    )

    print("JDBC connectivity test succeeded.")
    print(f"Rows returned: {test_df.count()}")
    display(test_df)

    # If token-based auth is not enabled for the caller, use a Key Vault-backed
    # SQL credential path instead of storing any secret in the notebook.
