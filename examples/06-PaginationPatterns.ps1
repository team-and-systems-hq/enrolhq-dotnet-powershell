<#
.SYNOPSIS
    Pagination patterns for working with large EnrolHQ datasets.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'your-token'

# --- Single page with metadata ---
$page = Get-EnrolHQApplications -Page 1 -PageSize 25
Write-Host "Page $($page.Page) of $($page.TotalPages) ($($page.Count) total records)"
Write-Host "This page has $($page.Results.Count) results"

# --- Auto-pagination (recommended) ---
$all = Get-EnrolHQApplications -EntryYear 2026 -All
Write-Host "`nAuto-paginated: $($all.Count) records"

# --- Manual pagination loop ---
$currentPage = 1
$allResults = @()
do {
    $page = Get-EnrolHQApplications -Page $currentPage -PageSize 100 -EntryYear 2026
    $allResults += $page.Results
    Write-Host "Fetched page $currentPage/$($page.TotalPages)"
    $currentPage++
} while ($page.Next)
Write-Host "Total collected: $($allResults.Count)"

# --- Stream-process large datasets ---
$page = Get-EnrolHQApplications -Page 1 -PageSize 100 -EntryYear 2026
for ($p = 1; $p -le $page.TotalPages; $p++) {
    $page = Get-EnrolHQApplications -Page $p -PageSize 100 -EntryYear 2026
    foreach ($app in $page.Results) {
        # Process each record individually
    }
    Write-Host "Processed page $p/$($page.TotalPages)"
}

Disconnect-EnrolHQ
