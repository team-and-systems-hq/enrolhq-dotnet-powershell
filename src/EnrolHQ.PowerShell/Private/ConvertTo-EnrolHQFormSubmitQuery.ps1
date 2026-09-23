function ConvertTo-EnrolHQFormSubmitQuery {
    <#
    .SYNOPSIS
        Builds the forms/staff-submits/ query string from cmdlet parameters.
    .DESCRIPTION
        Shared by Get-EnrolHQFormSubmits and Export-EnrolHQFormSubmits so the
        filter-to-query mapping (form, entry_year, entry_grade, is_completed,
        application_statuses) lives in one place. Uses ContainsKey rather than
        truthiness so a status of 0 (EnquiryOnline) is not dropped.
    .PARAMETER BoundParameters
        The calling cmdlet's $PSBoundParameters.
    .PARAMETER QueryParameters
        Extra query parameters to merge in first.
    .NOTES
        Private function.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$BoundParameters,

        [Parameter()]
        [hashtable]$QueryParameters = @{}
    )

    $queryParams = @{} + $QueryParameters

    if ($BoundParameters.ContainsKey('Form'))        { $queryParams['form'] = $BoundParameters['Form'] }
    if ($BoundParameters.ContainsKey('EntryYear'))   { $queryParams['entry_year'] = $BoundParameters['EntryYear'] }
    if ($BoundParameters.ContainsKey('EntryGrade'))  { $queryParams['entry_grade'] = $BoundParameters['EntryGrade'] }
    if ($BoundParameters.ContainsKey('IsCompleted')) { $queryParams['is_completed'] = ([bool]$BoundParameters['IsCompleted']).ToString().ToLower() }
    if ($BoundParameters.ContainsKey('ApplicationStatus')) {
        $queryParams['application_statuses'] = (@($BoundParameters['ApplicationStatus']) -join ',')
    }

    $queryParams
}
