<#
.SYNOPSIS
    Search and filter EnrolHQ applications.
.NOTES
    Run 01-GettingStarted.ps1 first to understand connection setup.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'yourschool' -ApiToken 'your-token'

# Search by name
$page = Get-EnrolHQApplications -Search 'Smith' -PageSize 10
Write-Host "Found $($page.Count) applications matching 'Smith'"
foreach ($app in $page.Results) {
    Write-Host "  $($app.first_name) $($app.last_name)"
}

# Filter by entry year + grade
$year7 = Get-EnrolHQApplications -EntryYear 2026 -EntryGrade 7 -All
Write-Host "`nYear 7 2026 applications: $($year7.Count)"

# Filter by application status codes
# 0 = EnquiryOnline, 1 = EnquiryManual, 2 = EOI, 4 = Enrolment
$page = Get-EnrolHQApplications -ApplicationStatus @(0, 1) -PageSize 10
Write-Host "`nEnquiries: $($page.Count) total"

# Using the EnrolHQStatus class for readable code
$eoi = Get-EnrolHQApplications `
    -ApplicationStatus @([EnrolHQStatus]::Eoi, [EnrolHQStatus]::Enrolment) `
    -PageSize 10
Write-Host "EOI + Enrolment: $($eoi.Count) total"

# Count without fetching records (faster for dashboards)
$count = Get-EnrolHQApplicationCount -EntryYear 2026
Write-Host "`nTotal 2026 applications: $count"

$countByGrade = Get-EnrolHQApplicationCount -EntryYear 2026 -EntryGrade 7
Write-Host "Total Year 7 2026: $countByGrade"

# Export to CSV (auto-paginate all results)
$all = Get-EnrolHQApplications -EntryYear 2026 -All
$all | Select-Object id, first_name, last_name, application_status, entry_grade, entry_year |
    Export-Csv -Path './applications-2026.csv' -NoTypeInformation
Write-Host "`nExported $($all.Count) applications to applications-2026.csv"

Disconnect-EnrolHQ
