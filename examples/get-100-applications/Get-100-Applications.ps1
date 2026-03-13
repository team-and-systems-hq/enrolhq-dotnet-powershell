<#
.SYNOPSIS
    Fetch 100 applications from EnrolHQ.
.DESCRIPTION
    Loads credentials from a .env file, connects to the EnrolHQ API,
    and retrieves the first 100 applications.
.NOTES
    Prerequisites: PowerShell 7+, a .env file with ENROLHQ_BASE_URL and ENROLHQ_API_TOKEN.
#>

#Requires -Version 7.0

# Load .env file
Get-Content "$PSScriptRoot/.env" | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim())
    }
}

# Import the module
Import-Module "$PSScriptRoot/../../src/EnrolHQ.PowerShell" -Force

# Connect (picks up ENROLHQ_BASE_URL and ENROLHQ_API_TOKEN from environment)
Connect-EnrolHQ

# Fetch 100 applications
$page = Get-EnrolHQApplications -PageSize 100

Write-Host "Total applications: $($page.Count)"
Write-Host "Returned: $($page.Results.Count)"
Write-Host ""

foreach ($app in $page.Results) {
    Write-Host "  $($app.id) | $($app.first_name) $($app.last_name) | Status: $($app.application_status) | Entry Year: $($app.entry_year)"
}

Disconnect-EnrolHQ
