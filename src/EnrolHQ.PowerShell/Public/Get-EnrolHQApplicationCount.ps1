function Get-EnrolHQApplicationCount {
    <#
    .SYNOPSIS
        Gets the count of EnrolHQ applications matching filters.
    .DESCRIPTION
        Returns just the total count of applications matching the specified filters,
        without fetching the actual records. Useful for dashboards and reporting.
    .PARAMETER EntryYear
        Filter by entry year.
    .PARAMETER EntryGrade
        Filter by entry grade.
    .PARAMETER ApplicationStatus
        Filter by one or more application status codes.
    .EXAMPLE
        Get-EnrolHQApplicationCount -EntryYear 2026

        Get total count of 2026 applications.
    .EXAMPLE
        Get-EnrolHQApplicationCount -EntryYear 2026 -ApplicationStatus @(0, 1)

        Count online and manual enquiries for 2026.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$EntryYear,

        [Parameter()]
        [int]$EntryGrade,

        [Parameter()]
        [int[]]$ApplicationStatus,

        [Parameter()]
        [int[]]$ExcludeStatus,

        [Parameter()]
        [string]$Search,

        [Parameter()]
        [string]$Campus
    )

    $queryParams = @{}
    if ($PSBoundParameters.ContainsKey('EntryYear'))    { $queryParams['entry_year'] = $EntryYear }
    if ($PSBoundParameters.ContainsKey('EntryGrade'))   { $queryParams['entry_grade'] = $EntryGrade }
    if ($PSBoundParameters.ContainsKey('Search'))       { $queryParams['search'] = $Search }
    if ($PSBoundParameters.ContainsKey('Campus'))       { $queryParams['campus'] = $Campus }
    if ($ApplicationStatus) { $queryParams['application_statuses'] = ($ApplicationStatus -join ',') }
    if ($ExcludeStatus)     { $queryParams['exclude_application_statuses'] = ($ExcludeStatus -join ',') }

    $response = Invoke-EnrolHQRestMethod -Method GET -Endpoint 'applications-list/count/' -QueryParameters $queryParams

    if ($response) {
        $response.count
    }
}
