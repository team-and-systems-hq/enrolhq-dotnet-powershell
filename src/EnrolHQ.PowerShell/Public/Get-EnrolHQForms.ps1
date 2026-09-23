function Get-EnrolHQForms {
    <#
    .SYNOPSIS
        Lists the forms defined for the school.
    .DESCRIPTION
        Custom forms (medical updates, permission/consent forms, transition
        surveys, scholarship registrations) are how schools collect data that
        has no dedicated field on the application. Their answers are NOT
        returned by Get-EnrolHQApplications - see Get-EnrolHQFormAnswers.

        By default reads forms/staff/, which returns every form including the
        built-in stub forms (enquiry, event booking, ...). Each record has
        `id`, `title`, `form_slug`, `kind`, `is_active` and `is_private`.
        Filter on `kind -eq 'CUSTOM'` for the school's own forms.

        With -Published, reads forms/ instead: the parent-facing view of
        published custom forms, which includes each form's audience rules
        (`allowed_entry_years`, `allowed_entry_grades`,
        `allowed_application_statuses`, `allowed_campuses`) and payment
        settings.

        Returns a single page by default. Use -All to auto-paginate.
    .PARAMETER Published
        Return only published (parent-facing) custom forms, with audience
        rules, from forms/.
    .PARAMETER QueryParameters
        Optional additional query parameters.
    .PARAMETER PageSize
        Number of results per page. Default: 100.
    .PARAMETER Page
        Specific page number to retrieve.
    .PARAMETER All
        Auto-paginate through all results. Returns all records.
    .EXAMPLE
        Get-EnrolHQForms -All | Where-Object kind -eq 'CUSTOM' |
            Select-Object title, form_slug, id

        List the school's custom forms.
    .EXAMPLE
        Get-EnrolHQForms -Published -All |
            Select-Object title, allowed_entry_years, allowed_entry_grades
    #>
    [CmdletBinding(DefaultParameterSetName = 'Page')]
    param(
        [Parameter()]
        [switch]$Published,

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

    $endpoint = if ($Published) { 'forms/' } else { 'forms/staff/' }
    Write-Verbose "Fetching forms from $endpoint"

    if ($All) {
        Get-EnrolHQAllPages -Endpoint $endpoint -QueryParameters $QueryParameters -PageSize $PageSize
    }
    else {
        $result = Get-EnrolHQPage -Endpoint $endpoint -QueryParameters $QueryParameters -Page $Page -PageSize $PageSize
        if ($result) {
            Write-Verbose "Page $($result.Page) of $($result.TotalPages) ($($result.Count) total records)"
            $result
        }
    }
}
