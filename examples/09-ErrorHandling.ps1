<#
.SYNOPSIS
    Error handling patterns for EnrolHQ PowerShell module.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'yourschool' -ApiToken 'your-token'

# --- Handling specific error types ---
try {
    $app = Get-EnrolHQApplication -Id 'nonexistent-uuid' -ErrorAction Stop
}
catch {
    switch -Wildcard ($_.FullyQualifiedErrorId) {
        'EnrolHQ.NotFoundError*'        { Write-Host 'Application not found' }
        'EnrolHQ.AuthenticationError*'  { Write-Host 'Auth failed - check token' }
        'EnrolHQ.ForbiddenError*'       { Write-Host 'Permission denied' }
        'EnrolHQ.ValidationError*'      { Write-Host "Validation: $($_.Exception.Message)" }
        'EnrolHQ.RateLimitError*'       { Write-Host 'Rate limited - wait and retry' }
        default                          { Write-Host "Error: $($_.Exception.Message)" }
    }
}

# --- Graceful degradation ---
$app = Get-EnrolHQApplication -Id 'some-uuid' -ErrorAction SilentlyContinue
if ($app) { Write-Host "Found: $($app.first_name)" }
else { Write-Host 'Not found, continuing...' }

# --- Verbose logging for debugging ---
Get-EnrolHQApplications -EntryYear 2026 -PageSize 5 -Verbose

Disconnect-EnrolHQ
