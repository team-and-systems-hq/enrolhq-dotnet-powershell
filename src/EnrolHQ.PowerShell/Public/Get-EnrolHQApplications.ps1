function Get-EnrolHQApplications {
    <#
    .SYNOPSIS
        Lists EnrolHQ applications with optional filtering.
    .DESCRIPTION
        Retrieves student applications from the EnrolHQ API. Returns a single page
        by default. Use -All to auto-paginate through all results.
    .PARAMETER EntryYear
        Filter by entry year (e.g. 2026).
    .PARAMETER EntryGrade
        Filter by entry grade (e.g. 7 for Year 7).
    .PARAMETER ApplicationStatus
        Filter by one or more application status codes. Use [EnrolHQStatus] constants.
    .PARAMETER ExcludeStatus
        Exclude applications with these status codes.
    .PARAMETER Search
        Free-text search across name fields.
    .PARAMETER Campus
        Filter by campus ID.
    .PARAMETER FirstName
        Filter by first name.
    .PARAMETER LastName
        Filter by last name.
    .PARAMETER Dob
        Filter by date of birth (YYYY-MM-DD).
    .PARAMETER IsFavorite
        Filter by favourite flag.
    .PARAMETER Ordering
        Sort order (e.g. 'last_name', '-created_at').
    .PARAMETER ExternalId
        Filter by external ID.
    .PARAMETER HasExternalId
        Filter to only records with/without an external ID.
    .PARAMETER PageSize
        Number of results per page. Default: 100.
    .PARAMETER Page
        Specific page number to retrieve.
    .PARAMETER All
        Auto-paginate through all results. Returns all records.
    .EXAMPLE
        Get-EnrolHQApplications -EntryYear 2026

        Get the first page of 2026 applications.
    .EXAMPLE
        Get-EnrolHQApplications -EntryYear 2026 -EntryGrade 7 -All

        Get ALL Year 7 2026 applications (auto-paginated).
    .EXAMPLE
        Get-EnrolHQApplications -Search 'Smith' -PageSize 50

        Search for applications matching "Smith".
    .EXAMPLE
        Get-EnrolHQApplications -ApplicationStatus @([EnrolHQStatus]::Eoi, [EnrolHQStatus]::Enrolment)

        Filter by multiple statuses.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Page')]
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
        [string]$Campus,

        [Parameter()]
        [string]$FirstName,

        [Parameter()]
        [string]$LastName,

        [Parameter()]
        [string]$Dob,

        [Parameter()]
        [bool]$IsFavorite,

        [Parameter()]
        [string]$Ordering,

        [Parameter()]
        [string]$ExternalId,

        [Parameter()]
        [bool]$HasExternalId,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 100,

        [Parameter(ParameterSetName = 'Page')]
        [int]$Page = 1,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All
    )

    # Build query parameters from bound parameters
    $queryParams = @{}

    if ($PSBoundParameters.ContainsKey('EntryYear'))     { $queryParams['entry_year'] = $EntryYear }
    if ($PSBoundParameters.ContainsKey('EntryGrade'))     { $queryParams['entry_grade'] = $EntryGrade }
    if ($PSBoundParameters.ContainsKey('Search'))         { $queryParams['search'] = $Search }
    if ($PSBoundParameters.ContainsKey('Campus'))         { $queryParams['campus'] = $Campus }
    if ($PSBoundParameters.ContainsKey('FirstName'))      { $queryParams['first_name'] = $FirstName }
    if ($PSBoundParameters.ContainsKey('LastName'))       { $queryParams['last_name'] = $LastName }
    if ($PSBoundParameters.ContainsKey('Dob'))            { $queryParams['dob'] = $Dob }
    if ($PSBoundParameters.ContainsKey('IsFavorite'))     { $queryParams['is_favorite'] = $IsFavorite.ToString().ToLower() }
    if ($PSBoundParameters.ContainsKey('Ordering'))       { $queryParams['ordering'] = $Ordering }
    if ($PSBoundParameters.ContainsKey('ExternalId'))     { $queryParams['external_id'] = $ExternalId }
    if ($PSBoundParameters.ContainsKey('HasExternalId'))  { $queryParams['has_external_id'] = $HasExternalId.ToString().ToLower() }

    if ($ApplicationStatus) {
        $queryParams['application_statuses'] = ($ApplicationStatus -join ',')
    }
    if ($ExcludeStatus) {
        $queryParams['exclude_application_statuses'] = ($ExcludeStatus -join ',')
    }

    if ($All) {
        Get-EnrolHQAllPages -Endpoint 'applications-list/' -QueryParameters $queryParams -PageSize $PageSize
    }
    else {
        $result = Get-EnrolHQPage -Endpoint 'applications-list/' -QueryParameters $queryParams -Page $Page -PageSize $PageSize
        if ($result) {
            Write-Verbose "Page $($result.Page) of $($result.TotalPages) ($($result.Count) total records)"
            $result
        }
    }
}
