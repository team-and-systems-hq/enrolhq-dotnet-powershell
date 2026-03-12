<#
.SYNOPSIS
    Azure Functions PowerShell worker example for EnrolHQ integration.

.DESCRIPTION
    This directory contains the files needed for an Azure Functions app
    that runs on a timer trigger to sync EnrolHQ data.

    File structure:
      /EnrolHQSync/
        function.json    - Function trigger and binding configuration
        run.ps1          - Main function implementation
      profile.ps1        - Module loading on function app startup
      requirements.psd1  - Module dependencies
      host.json          - Function host configuration

    This script file contains all the code for each file, separated by
    headers. In a real deployment, each section would be its own file.

.NOTES
    Azure Functions runtime: PowerShell 7.4
    Trigger: Timer (runs every day at 6:00 AM UTC)
    Required app settings:
      - ENROLHQ_INSTANCE
      - ENROLHQ_API_TOKEN (store in Key Vault and reference via app setting)
      - REPORT_STORAGE_CONNECTION (Azure Storage connection string)
#>

# ============================================================================
# FILE: host.json
# ============================================================================
# Place this at the root of your Azure Functions app.

<#
{
    "version": "2.0",
    "logging": {
        "applicationInsights": {
            "samplingSettings": {
                "isEnabled": true,
                "excludedTypes": "Request"
            }
        },
        "logLevel": {
            "default": "Information",
            "Host.Results": "Error",
            "Function": "Information",
            "Host.Aggregator": "Trace"
        }
    },
    "managedDependency": {
        "enabled": true
    },
    "extensionBundle": {
        "id": "Microsoft.Azure.Functions.ExtensionBundle",
        "version": "[4.*, 5.0.0)"
    }
}
#>

# ============================================================================
# FILE: requirements.psd1
# ============================================================================
# Place this at the root of your Azure Functions app.
# Azure Functions will automatically install these modules.

<#
@{
    'Az.Accounts'        = '3.*'
    'Az.KeyVault'        = '5.*'
    'Az.Storage'         = '6.*'
    'EnrolHQ.PowerShell' = '1.*'
}
#>

# ============================================================================
# FILE: profile.ps1
# ============================================================================
# Place this at the root of your Azure Functions app.
# It runs once when the function app cold starts.

# profile.ps1 content:
<#
# Azure Functions profile - runs on cold start

# Authenticate with Azure using Managed Identity
if ($env:MSI_SECRET) {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity | Out-Null
    Write-Host "Connected to Azure using Managed Identity"
}

# Pre-import the EnrolHQ module for faster function execution
Import-Module EnrolHQ.PowerShell -ErrorAction Stop
Write-Host "EnrolHQ.PowerShell module loaded"
#>

# ============================================================================
# FILE: EnrolHQSync/function.json
# ============================================================================
# Timer trigger configuration. This function runs daily at 6:00 AM UTC.

<#
{
    "bindings": [
        {
            "name": "Timer",
            "type": "timerTrigger",
            "direction": "in",
            "schedule": "0 0 6 * * *",
            "runOnStartup": false,
            "useMonitor": true
        },
        {
            "name": "outputBlob",
            "type": "blob",
            "direction": "out",
            "path": "enrolhq-reports/daily/{DateTime:yyyy-MM-dd}.csv",
            "connection": "REPORT_STORAGE_CONNECTION"
        }
    ]
}
#>

# ============================================================================
# FILE: EnrolHQSync/run.ps1
# ============================================================================
# Main function implementation

param(
    [Parameter(Mandatory)]
    $Timer,

    [Parameter()]
    $TriggerMetadata
)

# ---- Function Configuration ----

$EntryYear = (Get-Date).Year + 1
$ErrorActionPreference = 'Stop'

# ---- Logging ----

Write-Host "EnrolHQSync function triggered at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
Write-Host "Timer past due: $($Timer.IsPastDue)"

if ($Timer.IsPastDue) {
    Write-Warning "Timer trigger is past due. Running catch-up execution."
}

# ---- Retrieve credentials ----

try {
    # Get the EnrolHQ instance from app settings
    $instance = $env:ENROLHQ_INSTANCE
    if (-not $instance) {
        throw "ENROLHQ_INSTANCE app setting is not configured"
    }

    # Get the API token from app settings
    # Best practice: store in Azure Key Vault and reference via:
    #   @Microsoft.KeyVault(VaultName=myvault;SecretName=EnrolHQ-ApiToken)
    $apiToken = $env:ENROLHQ_API_TOKEN
    if (-not $apiToken) {
        throw "ENROLHQ_API_TOKEN app setting is not configured"
    }

    Write-Host "Configuration loaded for instance: $instance"
}
catch {
    Write-Error "Configuration error: $($_.Exception.Message)"
    throw
}

# ---- Connect to EnrolHQ ----

try {
    Connect-EnrolHQ `
        -Instance $instance `
        -ApiToken $apiToken

    Write-Host "Connected to EnrolHQ instance: $instance"
}
catch {
    Write-Error "Connection failed: $($_.Exception.Message)"
    throw
}

# ---- Fetch today's data ----

try {
    # Get all applications for the target entry year
    $applications = Get-EnrolHQApplications `
        -EntryYear $EntryYear `
        -All `
        -PageSize 100

    Write-Host "Fetched $($applications.Count) applications for $EntryYear entry"

    # Get reference data for enrichment
    $campuses = Get-EnrolHQReferenceData -Type 'Campuses'

    Write-Host "Reference data loaded: $($campuses.Count) campuses"
}
catch {
    Write-Error "Data fetch failed: $($_.Exception.Message)"
    throw
}

# ---- Generate daily snapshot report ----

try {
    $reportData = $applications | ForEach-Object {
        [PSCustomObject]@{
            ApplicationId     = $_.id
            StudentFirstName  = $_.student_first_name
            StudentLastName   = $_.student_last_name
            EntryYear         = $_.entry_year
            EntryGrade        = $_.entry_grade
            Status            = $_.status
            ParentName        = "$($_.parent_first_name) $($_.parent_last_name)"
            ParentEmail       = $_.parent_email
            CurrentSchool     = $_.current_school
            Boarding          = $_.boarding
            Scholarship       = $_.scholarship_applied
            CreatedDate       = $_.created_at
            LastUpdated       = $_.updated_at
            SnapshotDate      = Get-Date -Format 'yyyy-MM-dd'
        }
    }

    # Generate CSV content for the output blob binding
    $csvContent = $reportData | ConvertTo-Csv -NoTypeInformation | Out-String

    # Write to output binding (Azure Blob Storage)
    Push-OutputBinding -Name outputBlob -Value $csvContent

    Write-Host "Report written to blob storage: $($reportData.Count) records"
}
catch {
    Write-Error "Report generation failed: $($_.Exception.Message)"
    throw
}

# ---- Generate summary statistics ----

$statusSummary = $applications |
    Group-Object -Property status |
    Sort-Object -Property Count -Descending

$gradeSummary = $applications |
    Group-Object -Property entry_grade |
    Sort-Object -Property Name

Write-Host "`n=== Daily Summary for $EntryYear Entry ==="
Write-Host "Total applications: $($applications.Count)"
Write-Host ""
Write-Host "By status:"
foreach ($group in $statusSummary) {
    Write-Host "  $($group.Name): $($group.Count)"
}
Write-Host ""
Write-Host "By grade:"
foreach ($group in $gradeSummary) {
    Write-Host "  $($group.Name): $($group.Count)"
}

# ---- Check for anomalies ----

# Flag if there are significantly more applications than expected
$yesterday = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
$newToday = $applications | Where-Object { $_.created_at -ge $yesterday }

if ($newToday.Count -gt 50) {
    Write-Warning "Unusual activity: $($newToday.Count) new applications in the last 24 hours"
}

# ---- Completion ----

Write-Host "`nEnrolHQSync completed successfully at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"

# ============================================================================
# FILE: EnrolHQSync-HttpTrigger/function.json (bonus: HTTP trigger variant)
# ============================================================================
# An HTTP-triggered version for on-demand report generation.

<#
{
    "bindings": [
        {
            "authLevel": "function",
            "type": "httpTrigger",
            "direction": "in",
            "name": "Request",
            "methods": ["get"],
            "route": "reports/applications"
        },
        {
            "type": "http",
            "direction": "out",
            "name": "Response"
        }
    ]
}
#>

# ============================================================================
# FILE: EnrolHQSync-HttpTrigger/run.ps1 (HTTP trigger implementation)
# ============================================================================

<#
param(
    [Parameter(Mandatory)]
    $Request,

    [Parameter()]
    $TriggerMetadata
)

$ErrorActionPreference = 'Stop'

try {
    # Parse query parameters
    $entryYear = $Request.Query.entry_year
    if (-not $entryYear) { $entryYear = (Get-Date).Year + 1 }

    $format = $Request.Query.format
    if (-not $format) { $format = 'json' }

    # Connect and fetch data
    Connect-EnrolHQ -Instance $env:ENROLHQ_INSTANCE -ApiToken $env:ENROLHQ_API_TOKEN

    $applications = Get-EnrolHQApplications -EntryYear $entryYear -All -PageSize 100

    # Build response based on requested format
    if ($format -eq 'csv') {
        $csvContent = $applications |
            Select-Object id, student_first_name, student_last_name, entry_year,
                entry_grade, status, parent_email, created_at |
            ConvertTo-Csv -NoTypeInformation |
            Out-String

        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = [System.Net.HttpStatusCode]::OK
            ContentType = 'text/csv'
            Headers     = @{ 'Content-Disposition' = "attachment; filename=applications-$entryYear.csv" }
            Body        = $csvContent
        })
    }
    else {
        $summary = @{
            entry_year  = [int]$entryYear
            total       = $applications.Count
            by_status   = ($applications | Group-Object status | ForEach-Object {
                @{ status = $_.Name; count = $_.Count }
            })
            by_grade    = ($applications | Group-Object entry_grade | ForEach-Object {
                @{ grade = $_.Name; count = $_.Count }
            })
            generated   = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
        }

        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = [System.Net.HttpStatusCode]::OK
            ContentType = 'application/json'
            Body        = ($summary | ConvertTo-Json -Depth 5)
        })
    }
}
catch {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [System.Net.HttpStatusCode]::InternalServerError
        Body       = (@{ error = $_.Exception.Message } | ConvertTo-Json)
    })
}
#>
