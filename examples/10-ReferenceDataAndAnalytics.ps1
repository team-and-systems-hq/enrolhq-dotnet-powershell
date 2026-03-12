<#
.SYNOPSIS
    Fetch reference data and analytics from EnrolHQ.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'yourschool' -ApiToken 'your-token'

# --- Reference Data ---
$campuses = Get-EnrolHQReferenceData -Type Campuses
Write-Host "Campuses ($($campuses.Count)):"
$campuses | ForEach-Object { Write-Host "  $($_.name)" }

$countries = Get-EnrolHQReferenceData -Type Countries
Write-Host "`nCountries: $($countries.Count)"

$languages = Get-EnrolHQReferenceData -Type Languages
Write-Host "Languages: $($languages.Count)"

$attendanceTypes = Get-EnrolHQReferenceData -Type AttendanceTypes
Write-Host "`nAttendance Types:"
$attendanceTypes | ForEach-Object { Write-Host "  $($_.name)" }

# --- Analytics ---
$stats = Get-EnrolHQAnalytics -Report Statistics
Write-Host "`nApplication Statistics:"
$stats | ConvertTo-Json -Depth 3 | Write-Host

$conversion = Get-EnrolHQAnalytics -Report Conversion -QueryParameters @{ entry_year = 2026 }
Write-Host "`nConversion Data:"
$conversion | ConvertTo-Json -Depth 3 | Write-Host

Disconnect-EnrolHQ
