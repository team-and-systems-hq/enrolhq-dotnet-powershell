function Get-EnrolHQFormSubmits {
    <#
    .SYNOPSIS
        Lists custom form submissions with optional filtering.
    .DESCRIPTION
        Reads forms/staff-submits/ - the data behind the dashboard's
        "Custom Form Submits" report.

        Records are summaries: `form_id`, `created_at`, `completed_at`,
        `form_pdf` and a nested `student_profile`. They carry NEITHER the
        answers NOR the submit's own id, so you cannot feed them straight into
        Get-EnrolHQFormSubmit -Id. To get answers, use:
          Get-EnrolHQFormSubmit -ApplicationId  - full submits for one
                                                  application
          Get-EnrolHQFormAnswers -Form          - labelled answers in bulk
                                                  (one request per application)
          Export-EnrolHQFormSubmits             - everything flattened to CSV
                                                  in a single request

        Returns a single page by default. Use -All to auto-paginate.
    .PARAMETER Form
        A form UUID (from Get-EnrolHQForms / Get-EnrolHQForm). Sent as the
        `form` query parameter - note it is `form`, NOT `form_id`, even though
        the field is called `form_id` in the response.
    .PARAMETER EntryYear
        Filter by the student's entry year.
    .PARAMETER EntryGrade
        Filter by the student's entry grade.
    .PARAMETER ApplicationStatus
        Filter by one or more application status codes.
    .PARAMETER IsCompleted
        $true for submitted forms, $false for started-but-not-finished.
    .PARAMETER QueryParameters
        Optional additional query parameters.
    .PARAMETER PageSize
        Number of results per page. Default: 100.
    .PARAMETER Page
        Specific page number to retrieve.
    .PARAMETER All
        Auto-paginate through all results. Returns all records.
    .EXAMPLE
        Get-EnrolHQFormSubmits -Form $form.id -EntryYear 2027 -IsCompleted $true -All |
            ForEach-Object { "$($_.student_profile.last_name) $($_.completed_at)" }
    .EXAMPLE
        (Get-EnrolHQFormSubmits -Form $form.id -IsCompleted $false -PageSize 1).Count

        Count incomplete submissions cheaply - the page carries the total.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Page')]
    param(
        [Parameter()]
        [string]$Form,

        [Parameter()]
        [int]$EntryYear,

        [Parameter()]
        [int]$EntryGrade,

        [Parameter()]
        [int[]]$ApplicationStatus,

        [Parameter()]
        [bool]$IsCompleted,

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

    $queryParams = ConvertTo-EnrolHQFormSubmitQuery -BoundParameters $PSBoundParameters -QueryParameters $QueryParameters

    if ($All) {
        Get-EnrolHQAllPages -Endpoint 'forms/staff-submits/' -QueryParameters $queryParams -PageSize $PageSize
    }
    else {
        $result = Get-EnrolHQPage -Endpoint 'forms/staff-submits/' -QueryParameters $queryParams -Page $Page -PageSize $PageSize
        if ($result) {
            Write-Verbose "Page $($result.Page) of $($result.TotalPages) ($($result.Count) total records)"
            $result
        }
    }
}
