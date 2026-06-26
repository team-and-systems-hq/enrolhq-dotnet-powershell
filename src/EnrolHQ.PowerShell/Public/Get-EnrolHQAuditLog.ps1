function Get-EnrolHQAuditLog {
    <#
    .SYNOPSIS
        Retrieves the audit / change log for a student profile or parent.
    .DESCRIPTION
        Reads the read-only audit log (audit/log/). Each entry has a list of
        human-readable `changes`, plus `updated_at` and `updated_by`.

        This endpoint uses cursor pagination (no total count); all pages are
        followed automatically and the combined entries are returned.

        Filter by exactly one subject — a student profile or a parent.
    .PARAMETER StudentProfileId
        The student profile UUID whose audit log to read.
    .PARAMETER ParentId
        The parent UUID whose audit log to read.
    .PARAMETER PageSize
        Records fetched per request. Default: 25.
    .PARAMETER QueryParameters
        Optional additional query parameters.
    .EXAMPLE
        Get-EnrolHQAuditLog -StudentProfileId '11111111-1111-1111-1111-111111111111'

        Get every audit-log entry for a student profile.
    .EXAMPLE
        Get-EnrolHQAuditLog -ParentId '22222222-2222-2222-2222-222222222222' -PageSize 50
    #>
    [CmdletBinding(DefaultParameterSetName = 'StudentProfile')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'StudentProfile', Position = 0)]
        [string]$StudentProfileId,

        [Parameter(Mandatory, ParameterSetName = 'Parent')]
        [string]$ParentId,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 25,

        [Parameter()]
        [hashtable]$QueryParameters = @{}
    )

    $params = @{} + $QueryParameters
    if ($PSCmdlet.ParameterSetName -eq 'StudentProfile') {
        $params['student_profile'] = $StudentProfileId
    }
    else {
        $params['parent'] = $ParentId
    }

    Write-Verbose "Fetching audit log from audit/log/ ($($PSCmdlet.ParameterSetName))"

    Get-EnrolHQAllCursorPages -Endpoint 'audit/log/' -QueryParameters $params -PageSize $PageSize
}
