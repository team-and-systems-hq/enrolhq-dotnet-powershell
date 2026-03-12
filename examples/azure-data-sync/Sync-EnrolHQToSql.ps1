<#
.SYNOPSIS
    Syncs EnrolHQ applications into Azure SQL Database.

.DESCRIPTION
    Pulls all applications from EnrolHQ and upserts them into Azure SQL.
    Tracks status changes in an audit table and writes a daily snapshot
    for trend reporting in Power BI.

    Run as:
      - Azure Automation runbook (scheduled nightly)
      - Windows Task Scheduler job
      - Manual ad-hoc sync

.NOTES
    Prerequisites:
      1. Run Schema.sql against your Azure SQL database first
      2. Install modules: SqlServer, EnrolHQ.PowerShell
      3. Set up credentials (see below)

    For Azure Automation:
      - Store EnrolHQ creds as Automation Variables
      - Store SQL connection string as Automation Variable
      - Import SqlServer + EnrolHQ.PowerShell modules
#>

#Requires -Modules EnrolHQ.PowerShell, SqlServer

param(
    # Which entry years to sync. Defaults to current and next year.
    [int[]]$EntryYears = @((Get-Date).Year, (Get-Date).Year + 1),

    # Azure SQL connection string
    [string]$SqlConnectionString,

    # EnrolHQ instance name
    [string]$EnrolHQInstance,

    # EnrolHQ API token
    [string]$EnrolHQToken
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# 1. Resolve credentials
# ============================================================================

# Try Azure Automation variables first, then params, then env vars
if (-not $SqlConnectionString) {
    if (Get-Command 'Get-AutomationVariable' -ErrorAction SilentlyContinue) {
        $SqlConnectionString = Get-AutomationVariable -Name 'EnrolHQ-SqlConnectionString'
        $EnrolHQInstance      = Get-AutomationVariable -Name 'EnrolHQ-Instance'
        $EnrolHQToken         = Get-AutomationVariable -Name 'EnrolHQ-ApiToken'
    }
    else {
        $SqlConnectionString = $env:ENROLHQ_SQL_CONNECTION_STRING
        $EnrolHQInstance      = $env:ENROLHQ_INSTANCE
        $EnrolHQToken         = $env:ENROLHQ_API_TOKEN
    }
}

if (-not $SqlConnectionString) { throw 'SQL connection string is required.' }
if (-not $EnrolHQInstance)      { throw 'EnrolHQ instance name is required.' }
if (-not $EnrolHQToken)         { throw 'EnrolHQ API token is required.' }

# ============================================================================
# 2. Status label lookup
# ============================================================================

$StatusLabels = @{
    -1 = 'Archived';           0 = 'Enquiry (Online)';     1 = 'Enquiry (Manual)'
     2 = 'EOI';                3 = 'Interview';            4 = 'Enrolment'
     5 = 'Offer of Enrolment'; 6 = 'Accepted';             7 = 'Enrolled'
     8 = 'Deferred';           9 = 'Waitlisted';          10 = 'Withdrawn by Parent'
    11 = 'Declined by School'; 12 = 'Closed';             13 = 'Enquiry (Event)'
    14 = 'Enquiry (Tour)';    15 = 'Enquiry (Referred)';  16 = 'Enquiry (Phone)'
    17 = 'Enquiry (Walk-in)'; 18 = 'Reserved';            19 = 'Offer of Reserved Place'
    20 = 'Accepted Reserved'; 21 = 'Declined by Parent';  22 = 'Cancelled by School'
}

# ============================================================================
# 3. Helper: run SQL with parameters
# ============================================================================

function Invoke-Sql {
    param([string]$Query, [hashtable]$Parameters = @{})
    $params = @{
        ConnectionString = $SqlConnectionString
        Query            = $Query
        ErrorAction      = 'Stop'
    }
    if ($Parameters.Count -gt 0) {
        $params['Variable'] = $Parameters.GetEnumerator() | ForEach-Object {
            "$($_.Key)=$($_.Value)"
        }
    }
    Invoke-Sqlcmd @params
}

# ============================================================================
# 4. Log sync start
# ============================================================================

$syncStarted = Get-Date
Write-Output "=== EnrolHQ -> Azure SQL Sync ==="
Write-Output "Started: $syncStarted"
Write-Output "Entry years: $($EntryYears -join ', ')"

Invoke-Sql -Query "
    INSERT INTO dbo.EnrolHQ_SyncLog (StartedAt, Status)
    VALUES ('$($syncStarted.ToString('o'))', 'Running')
"

$syncLogId = (Invoke-Sql -Query "
    SELECT MAX(Id) AS Id FROM dbo.EnrolHQ_SyncLog WHERE Status = 'Running'
").Id

# ============================================================================
# 5. Connect to EnrolHQ
# ============================================================================

try {
    Connect-EnrolHQ -Instance $EnrolHQInstance -ApiToken $EnrolHQToken
    Write-Output "Connected to EnrolHQ ($EnrolHQInstance)"
}
catch {
    $err = "Connection failed: $_"
    Invoke-Sql -Query "
        UPDATE dbo.EnrolHQ_SyncLog
        SET CompletedAt = SYSDATETIMEOFFSET(), Status = 'Failed', ErrorMessage = '$($err -replace "'","''")'
        WHERE Id = $syncLogId
    "
    throw $err
}

# ============================================================================
# 6. Sync reference data (campuses)
# ============================================================================

Write-Output "Syncing campuses..."
$campuses = Get-EnrolHQReferenceData -Type Campuses

foreach ($c in $campuses) {
    Invoke-Sql -Query "
        MERGE dbo.EnrolHQ_Campuses AS target
        USING (SELECT
            '$($c.id)'                          AS Id,
            N'$($c.name -replace "'","''")'     AS Name,
            '$($c.slug)'                        AS Slug,
            '$($c.email)'                       AS Email,
            '$($c.telephone)'                   AS Telephone
        ) AS source ON target.Id = source.Id
        WHEN MATCHED THEN UPDATE SET
            Name = source.Name, Slug = source.Slug,
            Email = source.Email, Telephone = source.Telephone,
            SyncedAt = SYSDATETIMEOFFSET()
        WHEN NOT MATCHED THEN INSERT (Id, Name, Slug, Email, Telephone)
            VALUES (source.Id, source.Name, source.Slug, source.Email, source.Telephone);
    "
}
Write-Output "  $($campuses.Count) campuses synced"

# ============================================================================
# 7. Sync applications (per entry year)
# ============================================================================

$totalSynced = 0
$totalStatusChanges = 0

foreach ($year in $EntryYears) {
    Write-Output "Fetching $year applications..."
    $apps = Get-EnrolHQApplications -EntryYear $year -All -PageSize 200
    Write-Output "  $($apps.Count) applications fetched"

    foreach ($app in $apps) {
        $id      = $app.id
        $status  = [int]$app.application_status
        $label   = $StatusLabels[$status] ?? "Unknown ($status)"

        # Safely extract parent info
        $p1First = ($app.user_parent.first_name ?? '') -replace "'","''"
        $p1Last  = ($app.user_parent.last_name ?? '')  -replace "'","''"
        $p1Email = ($app.user_parent.email ?? '')       -replace "'","''"
        $p1Phone = $app.user_parent.mobile_phone ?? ''
        $p2First = ($app.non_user_parent.first_name ?? '') -replace "'","''"
        $p2Last  = ($app.non_user_parent.last_name ?? '')  -replace "'","''"
        $p2Email = ($app.non_user_parent.email ?? '')       -replace "'","''"
        $p2Phone = $app.non_user_parent.mobile_phone ?? ''

        # Campus can be an object or string
        $campusName = if ($app.campus -is [string]) { $app.campus }
                      elseif ($app.campus.name) { $app.campus.name }
                      else { '' }
        $campusName = $campusName -replace "'","''"

        # Attendance type
        $attendType = if ($app.attendance_type -is [string]) { $app.attendance_type }
                      elseif ($app.attendance_type.name) { $app.attendance_type.name }
                      else { '' }

        # Check for status change before upserting
        $existing = Invoke-Sql -Query "
            SELECT ApplicationStatus FROM dbo.EnrolHQ_Applications WHERE Id = '$id'
        "

        if ($existing -and $existing.ApplicationStatus -ne $status) {
            Invoke-Sql -Query "
                INSERT INTO dbo.EnrolHQ_StatusHistory
                    (ApplicationId, PreviousStatus, NewStatus, PreviousLabel, NewLabel)
                VALUES (
                    '$id', $($existing.ApplicationStatus), $status,
                    N'$($StatusLabels[[int]$existing.ApplicationStatus] ?? 'Unknown')',
                    N'$label'
                )
            "
            $totalStatusChanges++
        }

        # Upsert application
        $dob       = if ($app.dob) { "'$($app.dob)'" } else { 'NULL' }
        $createdAt = if ($app.created_at) { "'$($app.created_at)'" } else { 'NULL' }
        $updatedAt = if ($app.updated_at) { "'$($app.updated_at)'" } else { 'NULL' }

        Invoke-Sql -Query "
            MERGE dbo.EnrolHQ_Applications AS target
            USING (SELECT '$id' AS Id) AS source ON target.Id = source.Id
            WHEN MATCHED THEN UPDATE SET
                FirstName = N'$(($app.first_name ?? '') -replace "'","''")',
                LastName = N'$(($app.last_name ?? '') -replace "'","''")',
                PreferredName = N'$(($app.preferred_name ?? '') -replace "'","''")',
                Dob = $dob,
                Gender = $($app.gender ?? 'NULL'),
                EntryGrade = $($app.entry_grade ?? 'NULL'),
                EntryYear = $($app.entry_year ?? 'NULL'),
                EntryTerm = $($app.entry_term ?? 'NULL'),
                ApplicationStatus = $status,
                StatusLabel = N'$label',
                Campus = N'$campusName',
                AttendanceType = N'$attendType',
                ExternalId = N'$($app.external_id ?? '')',
                IsFavorite = $(if ($app.is_favorite) { 1 } else { 0 }),
                HowHear = N'$(($app.how_hear ?? '') -replace "'","''")',
                CreatedAt = $createdAt,
                UpdatedAt = $updatedAt,
                ParentFirstName = N'$p1First', ParentLastName = N'$p1Last',
                ParentEmail = N'$p1Email', ParentPhone = N'$p1Phone',
                Parent2FirstName = N'$p2First', Parent2LastName = N'$p2Last',
                Parent2Email = N'$p2Email', Parent2Phone = N'$p2Phone',
                SyncedAt = SYSDATETIMEOFFSET()
            WHEN NOT MATCHED THEN INSERT (
                Id, FirstName, LastName, PreferredName, Dob, Gender,
                EntryGrade, EntryYear, EntryTerm, ApplicationStatus, StatusLabel,
                Campus, AttendanceType, ExternalId, IsFavorite, HowHear,
                CreatedAt, UpdatedAt,
                ParentFirstName, ParentLastName, ParentEmail, ParentPhone,
                Parent2FirstName, Parent2LastName, Parent2Email, Parent2Phone
            ) VALUES (
                '$id',
                N'$(($app.first_name ?? '') -replace "'","''")',
                N'$(($app.last_name ?? '') -replace "'","''")',
                N'$(($app.preferred_name ?? '') -replace "'","''")',
                $dob, $($app.gender ?? 'NULL'),
                $($app.entry_grade ?? 'NULL'), $($app.entry_year ?? 'NULL'),
                $($app.entry_term ?? 'NULL'), $status, N'$label',
                N'$campusName', N'$attendType',
                N'$($app.external_id ?? '')',
                $(if ($app.is_favorite) { 1 } else { 0 }),
                N'$(($app.how_hear ?? '') -replace "'","''")',
                $createdAt, $updatedAt,
                N'$p1First', N'$p1Last', N'$p1Email', N'$p1Phone',
                N'$p2First', N'$p2Last', N'$p2Email', N'$p2Phone'
            );
        "

        $totalSynced++
    }

    Write-Output "  $year: $($apps.Count) records upserted"
}

# ============================================================================
# 8. Write daily snapshot (for trend charts in Power BI)
# ============================================================================

Write-Output "Writing daily snapshot..."
$today = (Get-Date).ToString('yyyy-MM-dd')

foreach ($year in $EntryYears) {
    # Delete today's snapshot for this year (idempotent re-run)
    Invoke-Sql -Query "
        DELETE FROM dbo.EnrolHQ_DailySnapshot
        WHERE SnapshotDate = '$today' AND EntryYear = $year
    "

    # Insert fresh counts
    Invoke-Sql -Query "
        INSERT INTO dbo.EnrolHQ_DailySnapshot
            (SnapshotDate, EntryYear, ApplicationStatus, StatusLabel, Campus, ApplicationCount)
        SELECT
            '$today', EntryYear, ApplicationStatus, StatusLabel,
            ISNULL(NULLIF(Campus, ''), 'Unknown'),
            COUNT(*)
        FROM dbo.EnrolHQ_Applications
        WHERE EntryYear = $year
        GROUP BY EntryYear, ApplicationStatus, StatusLabel, ISNULL(NULLIF(Campus, ''), 'Unknown')
    "
}

# ============================================================================
# 9. Log sync completion
# ============================================================================

$syncCompleted = Get-Date
$duration = ($syncCompleted - $syncStarted).TotalSeconds

Invoke-Sql -Query "
    UPDATE dbo.EnrolHQ_SyncLog
    SET CompletedAt = SYSDATETIMEOFFSET(),
        Status = 'Success',
        RecordsSynced = $totalSynced,
        StatusChanges = $totalStatusChanges
    WHERE Id = $syncLogId
"

Disconnect-EnrolHQ

Write-Output ""
Write-Output "=== Sync Complete ==="
Write-Output "  Records synced:   $totalSynced"
Write-Output "  Status changes:   $totalStatusChanges"
Write-Output "  Duration:         $([math]::Round($duration, 1))s"
Write-Output "  Completed:        $syncCompleted"
