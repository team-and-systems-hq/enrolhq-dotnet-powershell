function Get-EnrolHQLeads {
    <#
    .SYNOPSIS
        Lists EnrolHQ leads (pre-enquiry contacts) with optional filtering.
    .DESCRIPTION
        A lead captures a contact (usually a parent) and optionally a
        prospective student before a full application exists - e.g. from a
        "keep me updated" website form. Each lead carries contact details, an
        optional nested `student`, a `residential_address`, a `reference`
        (lead reference UUID identifying which form/source it came from) and
        an optional `student_profile` link to an existing application.

        Returns a single page by default. Use -All to auto-paginate through
        all results.
    .PARAMETER IsEmailUnique
        Filter by whether the lead's email is unique in the instance.
    .PARAMETER HasStudentProfile
        $true for leads linked to a student profile/application, $false for
        standalone leads.
    .PARAMETER QueryParameters
        Optional additional query parameters.
    .PARAMETER PageSize
        Number of results per page. Default: 100.
    .PARAMETER Page
        Specific page number to retrieve.
    .PARAMETER All
        Auto-paginate through all results. Returns all records.
    .EXAMPLE
        Get-EnrolHQLeads -All

        Get every lead (auto-paginated).
    .EXAMPLE
        $page = Get-EnrolHQLeads -HasStudentProfile $false -PageSize 25
        "$($page.Count) leads without a linked profile"

        Count leads not yet linked to an application.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Page')]
    param(
        [Parameter()]
        [bool]$IsEmailUnique,

        [Parameter()]
        [bool]$HasStudentProfile,

        [Parameter()]
        [hashtable]$QueryParameters = @{},

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 100,

        [Parameter(ParameterSetName = 'Page')]
        [int]$Page = 1,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All
    )

    $queryParams = @{} + $QueryParameters

    if ($PSBoundParameters.ContainsKey('IsEmailUnique'))     { $queryParams['is_email_unique'] = $IsEmailUnique.ToString().ToLower() }
    if ($PSBoundParameters.ContainsKey('HasStudentProfile')) { $queryParams['has_student_profile'] = $HasStudentProfile.ToString().ToLower() }

    if ($All) {
        Get-EnrolHQAllPages -Endpoint 'leads/' -QueryParameters $queryParams -PageSize $PageSize
    }
    else {
        $result = Get-EnrolHQPage -Endpoint 'leads/' -QueryParameters $queryParams -Page $Page -PageSize $PageSize
        if ($result) {
            Write-Verbose "Page $($result.Page) of $($result.TotalPages) ($($result.Count) total records)"
            $result
        }
    }
}
