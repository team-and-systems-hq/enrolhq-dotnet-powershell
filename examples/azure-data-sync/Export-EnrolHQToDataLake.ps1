<#
.SYNOPSIS
    Exports EnrolHQ data to Azure Data Lake Storage Gen2 as CSV files.

.DESCRIPTION
    Pulls applications, reference data, and analytics from EnrolHQ and
    writes date-partitioned CSV files to an ADLS Gen2 container.

    Folder structure:
      enrolhq/
        applications/2026/2026-03-12.csv
        campuses/2026-03-12.csv
        analytics/statistics/2026-03-12.json
        analytics/conversion/2026-03-12.json

    Use this for:
      - Long-term archival / compliance
      - Synapse / Databricks / Fabric ingestion
      - Cheaper alternative to SQL for historical data

.NOTES
    Prerequisites:
      - Az.Storage module
      - Az.Accounts module (for managed identity or service principal)
      - EnrolHQ.PowerShell module
      - Storage account with hierarchical namespace (ADLS Gen2)

    For Azure Automation:
      - Enable managed identity on the Automation Account
      - Grant "Storage Blob Data Contributor" on the storage account
#>

#Requires -Modules EnrolHQ.PowerShell, Az.Storage, Az.Accounts

param(
    [int[]]$EntryYears = @((Get-Date).Year, (Get-Date).Year + 1),

    [string]$StorageAccountName,
    [string]$ContainerName = 'enrolhq',

    [string]$EnrolHQInstance,
    [string]$EnrolHQToken
)

$ErrorActionPreference = 'Stop'
$today = Get-Date -Format 'yyyy-MM-dd'

# ============================================================================
# 1. Resolve credentials
# ============================================================================

if (Get-Command 'Get-AutomationVariable' -ErrorAction SilentlyContinue) {
    # Azure Automation
    Connect-AzAccount -Identity | Out-Null
    $StorageAccountName = Get-AutomationVariable -Name 'EnrolHQ-StorageAccount'
    $ContainerName      = Get-AutomationVariable -Name 'EnrolHQ-Container' -ErrorAction SilentlyContinue
    $EnrolHQInstance     = Get-AutomationVariable -Name 'EnrolHQ-Instance'
    $EnrolHQToken        = Get-AutomationVariable -Name 'EnrolHQ-ApiToken'
    if (-not $ContainerName) { $ContainerName = 'enrolhq' }
}
else {
    # Local / CI — expect env vars or params
    if (-not $StorageAccountName) { $StorageAccountName = $env:ENROLHQ_STORAGE_ACCOUNT }
    if (-not $EnrolHQInstance)     { $EnrolHQInstance = $env:ENROLHQ_INSTANCE }
    if (-not $EnrolHQToken)        { $EnrolHQToken = $env:ENROLHQ_API_TOKEN }
}

if (-not $StorageAccountName) { throw 'Storage account name is required.' }
if (-not $EnrolHQInstance)    { throw 'EnrolHQ instance is required.' }
if (-not $EnrolHQToken)       { throw 'EnrolHQ API token is required.' }

# ============================================================================
# 2. Connect
# ============================================================================

Connect-EnrolHQ -Instance $EnrolHQInstance -ApiToken $EnrolHQToken
Write-Output "Connected to EnrolHQ ($EnrolHQInstance)"

$storageCtx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
Write-Output "Storage context: $StorageAccountName / $ContainerName"

# Ensure container exists
$null = Get-AzStorageContainer -Name $ContainerName -Context $storageCtx -ErrorAction SilentlyContinue
if (-not $?) {
    $null = New-AzStorageContainer -Name $ContainerName -Context $storageCtx
    Write-Output "Created container: $ContainerName"
}

# ============================================================================
# 3. Helper: upload a string as a blob
# ============================================================================

function Upload-Blob {
    param(
        [string]$BlobPath,
        [string]$Content,
        [string]$ContentType = 'text/csv'
    )

    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tempFile, $Content, [System.Text.Encoding]::UTF8)
        Set-AzStorageBlobContent `
            -Container $ContainerName `
            -Blob $BlobPath `
            -File $tempFile `
            -Context $storageCtx `
            -Properties @{ ContentType = $ContentType } `
            -Force | Out-Null
        Write-Output "  Uploaded: $BlobPath"
    }
    finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# 4. Export applications (per entry year)
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

$totalRecords = 0

foreach ($year in $EntryYears) {
    Write-Output "Exporting $year applications..."
    $apps = Get-EnrolHQApplications -EntryYear $year -All -PageSize 200

    if ($apps.Count -eq 0) {
        Write-Output "  No applications for $year, skipping"
        continue
    }

    # Flatten into table rows
    $rows = $apps | ForEach-Object {
        $status = [int]$_.application_status
        [PSCustomObject]@{
            Id                = $_.id
            FirstName         = $_.first_name
            LastName          = $_.last_name
            PreferredName     = $_.preferred_name
            Dob               = $_.dob
            Gender            = $_.gender
            EntryGrade        = $_.entry_grade
            EntryYear         = $_.entry_year
            EntryTerm         = $_.entry_term
            StatusCode        = $status
            StatusLabel       = $StatusLabels[$status] ?? "Unknown ($status)"
            Campus            = if ($_.campus -is [string]) { $_.campus } elseif ($_.campus.name) { $_.campus.name } else { '' }
            ExternalId        = $_.external_id
            IsFavorite        = $_.is_favorite
            HowHear           = $_.how_hear
            CreatedAt         = $_.created_at
            UpdatedAt         = $_.updated_at
            ParentFirstName   = $_.user_parent.first_name
            ParentLastName    = $_.user_parent.last_name
            ParentEmail       = $_.user_parent.email
            ParentPhone       = $_.user_parent.mobile_phone
            Parent2FirstName  = $_.non_user_parent.first_name
            Parent2LastName   = $_.non_user_parent.last_name
            Parent2Email      = $_.non_user_parent.email
            Parent2Phone      = $_.non_user_parent.mobile_phone
            ExportDate        = $today
        }
    }

    $csv = $rows | ConvertTo-Csv -NoTypeInformation | Out-String
    Upload-Blob -BlobPath "applications/$year/$today.csv" -Content $csv

    $totalRecords += $rows.Count
    Write-Output "  $($rows.Count) records exported for $year"
}

# ============================================================================
# 5. Export reference data
# ============================================================================

Write-Output "Exporting reference data..."

# Campuses
$campuses = Get-EnrolHQReferenceData -Type Campuses
$csv = $campuses | ForEach-Object {
    [PSCustomObject]@{
        Id        = $_.id
        Name      = $_.name
        Slug      = $_.slug
        Email     = $_.email
        Telephone = $_.telephone
    }
} | ConvertTo-Csv -NoTypeInformation | Out-String
Upload-Blob -BlobPath "reference/campuses/$today.csv" -Content $csv

# Countries (flat list)
$countries = Get-EnrolHQReferenceData -Type Countries
$csv = $countries | ConvertTo-Csv -NoTypeInformation | Out-String
Upload-Blob -BlobPath "reference/countries/$today.csv" -Content $csv

# Languages
$languages = Get-EnrolHQReferenceData -Type Languages
$csv = $languages | ConvertTo-Csv -NoTypeInformation | Out-String
Upload-Blob -BlobPath "reference/languages/$today.csv" -Content $csv

# ============================================================================
# 6. Export analytics snapshots (as JSON — richer structure)
# ============================================================================

Write-Output "Exporting analytics..."

foreach ($year in $EntryYears) {
    $qp = @{ entry_year = $year }

    # Statistics
    $stats = Get-EnrolHQAnalytics -Report Statistics -QueryParameters $qp
    $json = $stats | ConvertTo-Json -Depth 10
    Upload-Blob -BlobPath "analytics/statistics/$year/$today.json" -Content $json -ContentType 'application/json'

    # Conversion funnel
    $conversion = Get-EnrolHQAnalytics -Report Conversion -QueryParameters $qp
    $json = $conversion | ConvertTo-Json -Depth 10
    Upload-Blob -BlobPath "analytics/conversion/$year/$today.json" -Content $json -ContentType 'application/json'

    # Monthly trend
    $monthly = Get-EnrolHQAnalytics -Report MonthlyChart -QueryParameters $qp
    $json = $monthly | ConvertTo-Json -Depth 10
    Upload-Blob -BlobPath "analytics/monthly/$year/$today.json" -Content $json -ContentType 'application/json'
}

# ============================================================================
# 7. Write manifest (lets downstream jobs know the export is complete)
# ============================================================================

$manifest = @{
    export_date    = $today
    instance       = $EnrolHQInstance
    entry_years    = $EntryYears
    total_records  = $totalRecords
    completed_at   = (Get-Date).ToString('o')
    files          = @(
        $EntryYears | ForEach-Object { "applications/$_/$today.csv" }
        "reference/campuses/$today.csv"
        "reference/countries/$today.csv"
        "reference/languages/$today.csv"
        $EntryYears | ForEach-Object {
            "analytics/statistics/$_/$today.json"
            "analytics/conversion/$_/$today.json"
            "analytics/monthly/$_/$today.json"
        }
    )
} | ConvertTo-Json -Depth 5

Upload-Blob -BlobPath "manifests/$today.json" -Content $manifest -ContentType 'application/json'

# ============================================================================
# Done
# ============================================================================

Disconnect-EnrolHQ

Write-Output ""
Write-Output "=== Export Complete ==="
Write-Output "  Total records: $totalRecords"
Write-Output "  Entry years:   $($EntryYears -join ', ')"
Write-Output "  Storage:       $StorageAccountName/$ContainerName"
Write-Output "  Date:          $today"
