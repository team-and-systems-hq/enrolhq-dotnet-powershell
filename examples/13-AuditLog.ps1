<#
.SYNOPSIS
    Read the audit / change log for a student profile or a parent.
.DESCRIPTION
    The audit/log/ endpoint is read-only and cursor-paginated. Each entry has a
    list of human-readable `changes`, plus `updated_at` and `updated_by`. Filter
    by either a student profile or a parent.

    The audit log is cursor-paginated (no total count); Get-EnrolHQAuditLog
    follows the server's `next` cursor automatically and returns every entry.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'your-token'

# Replace with real IDs from your instance.
$studentProfileId = '11111111-1111-1111-1111-111111111111'
$parentId         = '22222222-2222-2222-2222-222222222222'

# Audit log for a student profile — every page is fetched automatically.
Write-Host "Audit log for student ${studentProfileId}:"
foreach ($entry in Get-EnrolHQAuditLog -StudentProfileId $studentProfileId) {
    $who = if ($entry.updated_by) { $entry.updated_by } else { 'system' }
    foreach ($change in $entry.changes) {
        Write-Host "  $($entry.updated_at) — ${who}: $change"
    }
}

# Audit log for a parent.
Write-Host "`nAudit log for parent ${parentId}:"
foreach ($entry in Get-EnrolHQAuditLog -ParentId $parentId -PageSize 50) {
    foreach ($change in $entry.changes) {
        Write-Host "  $($entry.updated_at): $change"
    }
}

Disconnect-EnrolHQ
