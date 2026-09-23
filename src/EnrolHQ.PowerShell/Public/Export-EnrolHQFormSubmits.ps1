function Export-EnrolHQFormSubmits {
    <#
    .SYNOPSIS
        Downloads the form-submits report as CSV.
    .DESCRIPTION
        Calls forms/staff-submits/export/ and saves the CSV to disk. The
        export flattens student details, emergency contacts, medical data and
        every answer into one row per submission, in a SINGLE request - the
        fastest path for a warehouse load. (Get-EnrolHQFormAnswers -Form
        returns the same data as objects but costs one request per
        application.)

        Accepts the same filters as Get-EnrolHQFormSubmits.
    .PARAMETER DestinationPath
        Local file path for the CSV. Parent directories are created.
    .PARAMETER Form
        A form UUID (sent as `form`, not `form_id`).
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
    .EXAMPLE
        Export-EnrolHQFormSubmits -DestinationPath ./consents.csv -Form $form.id -IsCompleted $true
        Import-Csv ./consents.csv | Select-Object 'profile.first_name', 'payload.group_3_social_media'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$DestinationPath,

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
        [hashtable]$QueryParameters = @{}
    )

    $queryParams = ConvertTo-EnrolHQFormSubmitQuery -BoundParameters $PSBoundParameters -QueryParameters $QueryParameters

    $destDir = Split-Path $DestinationPath -Parent
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Write-Verbose "Exporting form submits to $DestinationPath"
    # -ErrorAction Stop so a failed download terminates here instead of
    # handing back a stale file from an earlier run.
    Invoke-EnrolHQRestMethod -Method GET -Endpoint 'forms/staff-submits/export/' `
        -QueryParameters $queryParams -OutFile $DestinationPath -ErrorAction Stop | Out-Null

    Get-Item -Path $DestinationPath -ErrorAction SilentlyContinue
}
