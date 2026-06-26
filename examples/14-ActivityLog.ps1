<#
.SYNOPSIS
    List the activity log for a student profile.
.DESCRIPTION
    The activity-log/ endpoint returns timestamped activity entries (emails,
    status changes, notes, etc.) for a student profile. Each entry has an
    `activity_kind`, a `description`, `occurred_at` / `created_at` timestamps,
    `created_by`, and an optional `attachment_src`.

    Get-EnrolHQActivityLog auto-paginates, returning every entry.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'your-token'

# Replace with a real student profile UUID from your instance.
$studentProfileId = '11111111-1111-1111-1111-111111111111'

foreach ($entry in Get-EnrolHQActivityLog -StudentProfileId $studentProfileId) {
    $when = if ($entry.occurred_at) { $entry.occurred_at } else { $entry.created_at }
    $who  = if ($entry.created_by) { $entry.created_by } else { 'system' }
    $kind = $entry.activity_kind
    $summary = ($entry.description -split "`n")[0]
    Write-Host "$when [$kind] ${who}: $summary"
}

Disconnect-EnrolHQ
