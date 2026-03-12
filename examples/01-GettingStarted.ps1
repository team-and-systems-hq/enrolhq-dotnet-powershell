<#
.SYNOPSIS
    Getting started with the EnrolHQ PowerShell module.
.DESCRIPTION
    Demonstrates connecting, listing applications, and fetching reference data.
.NOTES
    Prerequisites: PowerShell 7+, an EnrolHQ account with API access.
    Get your API token from EnrolHQ: Profile icon (top-right) > API Token.
#>

#Requires -Version 7.0

# Import the module (adjust path if installed differently)
Import-Module ./src/EnrolHQ.PowerShell

# --- Option A: Connect with explicit parameters ---
Connect-EnrolHQ -Instance 'yourschool' -ApiToken 'your-api-token-here'

# --- Option B: Connect using environment variables ---
# $env:ENROLHQ_INSTANCE = 'yourschool'
# $env:ENROLHQ_API_TOKEN = 'your-api-token-here'
# Connect-EnrolHQ

# --- Option C: Connect with a full base URL ---
# Connect-EnrolHQ -BaseUrl 'https://yourschool.enrolhq.com.au/api/v2/' -ApiToken $token

# Fetch the first page of applications
$page = Get-EnrolHQApplications -PageSize 5
Write-Host "Total applications: $($page.Count)"
foreach ($app in $page.Results) {
    Write-Host "  $($app.first_name) $($app.last_name) - status $($app.application_status)"
}

# Fetch reference data
$campuses = Get-EnrolHQReferenceData -Type Campuses
Write-Host "`nCampuses: $($campuses.Count) found"
foreach ($c in $campuses) {
    Write-Host "  $($c.name)"
}

# Get a single application by ID
if ($page.Results.Count -gt 0) {
    $detail = Get-EnrolHQApplication -Id $page.Results[0].id
    Write-Host "`nApplication detail:"
    Write-Host "  Name: $($detail.first_name) $($detail.last_name)"
    Write-Host "  Entry: Year $($detail.entry_grade) in $($detail.entry_year)"
}

# Disconnect when done
Disconnect-EnrolHQ
