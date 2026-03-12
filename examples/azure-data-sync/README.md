# EnrolHQ -> Azure Data Sync

Sync EnrolHQ application data into Azure SQL Database or Azure Data Lake for
reporting (Power BI), SIS integration, and compliance archival.

## Quick Start

### Azure SQL

```powershell
# 1. Create tables
Invoke-Sqlcmd -InputFile ./Schema.sql -ConnectionString $connStr

# 2. Run the sync
./Sync-EnrolHQToSql.ps1 `
    -SqlConnectionString 'Server=tcp:myserver.database.windows.net;Database=SchoolDB;...' `
    -EnrolHQInstance 'myschool' `
    -EnrolHQToken $token
```

### Azure Data Lake

```powershell
Connect-AzAccount

./Export-EnrolHQToDataLake.ps1 `
    -StorageAccountName 'stschooldata' `
    -ContainerName 'enrolhq' `
    -EnrolHQInstance 'myschool' `
    -EnrolHQToken $token
```

## What Gets Synced

| Target | Table / Path | Contents |
|--------|-------------|----------|
| SQL | `EnrolHQ_Applications` | All applications with parent contacts |
| SQL | `EnrolHQ_StatusHistory` | Audit trail of status changes |
| SQL | `EnrolHQ_DailySnapshot` | Point-in-time counts for trend charts |
| SQL | `EnrolHQ_Campuses` | Campus reference data |
| SQL | `EnrolHQ_SyncLog` | Sync run history |
| Lake | `applications/{year}/{date}.csv` | Daily application snapshot |
| Lake | `reference/campuses/{date}.csv` | Campus reference data |
| Lake | `analytics/*/` | Statistics, conversion, monthly data |
| Lake | `manifests/{date}.json` | Export completion manifest |

## Azure Automation Setup

1. Import modules: `EnrolHQ.PowerShell`, `SqlServer`, `Az.Storage`
2. Create Automation Variables:
   - `EnrolHQ-Instance` (string)
   - `EnrolHQ-ApiToken` (encrypted string)
   - `EnrolHQ-SqlConnectionString` (encrypted string)
   - `EnrolHQ-StorageAccount` (string, for Data Lake)
3. Create a daily schedule (e.g. 6:00 AM AEST)
4. Import the runbook and link the schedule

## Power BI

After running the SQL sync, connect Power BI to Azure SQL and use the
pre-built views:

- `vw_EnrolHQ_Pipeline` — application counts by year/grade/status/campus
- `vw_EnrolHQ_ParentContacts` — parent contact list (active applications)
- `EnrolHQ_DailySnapshot` — trend data for line charts
