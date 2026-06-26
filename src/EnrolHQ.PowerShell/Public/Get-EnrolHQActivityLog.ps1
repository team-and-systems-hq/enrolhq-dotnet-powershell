function Get-EnrolHQActivityLog {
    <#
    .SYNOPSIS
        Retrieves the activity log for a student profile.
    .DESCRIPTION
        Reads the activity-log/ endpoint, which returns timestamped activity
        entries (emails, status changes, notes, etc.) for a student profile.
        Each entry has an `activity_kind`, a `description`, `occurred_at` /
        `created_at` timestamps, `created_by`, and an optional `attachment_src`.

        All pages are fetched automatically and the combined entries returned.
    .PARAMETER StudentProfileId
        The student profile UUID whose activity log to read.
    .PARAMETER PageSize
        Records fetched per request. Default: 1000.
    .PARAMETER QueryParameters
        Optional additional query parameters.
    .EXAMPLE
        Get-EnrolHQActivityLog -StudentProfileId '11111111-1111-1111-1111-111111111111'

        Get every activity-log entry for a student profile.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$StudentProfileId,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 1000,

        [Parameter()]
        [hashtable]$QueryParameters = @{}
    )

    $params = @{} + $QueryParameters
    $params['student_profile'] = $StudentProfileId

    Write-Verbose "Fetching activity log from activity-log/ for $StudentProfileId"

    Get-EnrolHQAllPages -Endpoint 'activity-log/' -QueryParameters $params -PageSize $PageSize
}
