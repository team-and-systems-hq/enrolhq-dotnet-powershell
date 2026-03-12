<#
.SYNOPSIS
    Azure Functions PowerShell worker - EnrolHQ application count API.
.DESCRIPTION
    Timer-triggered function that checks application counts and posts
    a summary to a webhook (e.g., Teams, Slack).

    Deploy as an Azure Functions PowerShell worker project.
    See function.json for trigger configuration.
#>

using namespace System.Net

param($Timer)

# Import module (loaded via requirements.psd1)
Import-Module EnrolHQ.PowerShell -ErrorAction Stop

# Get credentials from Key Vault (via app settings / managed identity)
$instance = $env:ENROLHQ_INSTANCE
$apiToken = $env:ENROLHQ_API_TOKEN  # Set via Azure Key Vault reference

if (-not $instance -or -not $apiToken) {
    Write-Error 'ENROLHQ_INSTANCE and ENROLHQ_API_TOKEN environment variables are required'
    return
}

try {
    Connect-EnrolHQ -Instance $instance -ApiToken $apiToken

    $entryYear = (Get-Date).Year + 1

    # Get counts by status
    $enquiryCount = Get-EnrolHQApplicationCount -EntryYear $entryYear -ApplicationStatus @(0, 1)
    $eoiCount = Get-EnrolHQApplicationCount -EntryYear $entryYear -ApplicationStatus @(2)
    $enrolmentCount = Get-EnrolHQApplicationCount -EntryYear $entryYear -ApplicationStatus @(4)
    $totalCount = Get-EnrolHQApplicationCount -EntryYear $entryYear

    $summary = @{
        text = @"
**EnrolHQ Daily Summary ($entryYear)**
- Total applications: $totalCount
- Enquiries: $enquiryCount
- EOI: $eoiCount
- Enrolment: $enrolmentCount
- Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
"@
    }

    Write-Host "Application counts - Total: $totalCount, Enquiries: $enquiryCount, EOI: $eoiCount, Enrolment: $enrolmentCount"

    # Post to webhook (Teams/Slack)
    $webhookUrl = $env:TEAMS_WEBHOOK_URL
    if ($webhookUrl) {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($summary | ConvertTo-Json) -ContentType 'application/json'
        Write-Host 'Summary posted to webhook'
    }
}
catch {
    Write-Error "Function failed: $_"
    throw
}
finally {
    Disconnect-EnrolHQ
}
