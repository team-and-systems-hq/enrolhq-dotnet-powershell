<#
.SYNOPSIS
    Azure Automation runbook for EnrolHQ reporting.
.DESCRIPTION
    Connects to EnrolHQ, generates a daily application summary.
    Setup:
    1. Upload EnrolHQ.PowerShell module to your Automation Account
    2. Create Automation Variables: EnrolHQ-Instance, EnrolHQ-ApiToken (encrypted)
    3. Schedule this runbook to run daily
#>

#Requires -Version 7.0

param([int]$EntryYear = (Get-Date).Year + 1)

Import-Module EnrolHQ.PowerShell -ErrorAction Stop

$instance = Get-AutomationVariable -Name 'EnrolHQ-Instance'
$apiToken = Get-AutomationVariable -Name 'EnrolHQ-ApiToken'

if (-not $instance -or -not $apiToken) {
    throw 'Missing Automation variables: EnrolHQ-Instance and EnrolHQ-ApiToken'
}

Write-Output "Connecting to $instance..."
Connect-EnrolHQ -Instance $instance -ApiToken $apiToken

try {
    $applications = Get-EnrolHQApplications -EntryYear $EntryYear -All
    Write-Output "Found $($applications.Count) applications for $EntryYear"

    $statusSummary = $applications | Group-Object application_status | Sort-Object Count -Descending
    Write-Output "`nStatus breakdown:"
    foreach ($g in $statusSummary) { Write-Output "  Status $($g.Name): $($g.Count)" }

    $gradeSummary = $applications | Group-Object entry_grade | Sort-Object Name
    Write-Output "`nGrade breakdown:"
    foreach ($g in $gradeSummary) { Write-Output "  Grade $($g.Name): $($g.Count)" }

    $csv = $applications |
        Select-Object id, first_name, last_name, application_status, entry_grade, entry_year |
        ConvertTo-Csv -NoTypeInformation
    Write-Output "`nReport: $($applications.Count) records generated"
}
catch {
    Write-Error "Runbook failed: $_"
    throw
}
finally {
    Disconnect-EnrolHQ
    Write-Output 'Runbook completed'
}
