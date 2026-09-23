function Get-EnrolHQFormSubmit {
    <#
    .SYNOPSIS
        Gets full form submissions, by submit ID or for one application.
    .DESCRIPTION
        -Id reads forms/staff-submits/{id}/ - a single submission including
        its `payload` (the parent's answers), `initial_payload` (profile data
        pre-filled when the form was opened) and `form_schema`.

        -ApplicationId returns every submission for one application, with
        full payloads. The forms/staff-submits/ endpoint has no
        per-application filter, so this reads the submit IDs off the
        application detail (`custom_form_submits`) and fetches each one. Pass
        -Form to return submissions for that form only.

        Each submit returned via -ApplicationId is annotated with `form_id`
        and `application_id`. The submit detail endpoint does not include
        them - its `form_schema.id` is a schema *version* id, not the form's
        id, so without this you cannot tell which form a submit belongs to.
    .PARAMETER Id
        The submit UUID.
    .PARAMETER ApplicationId
        The application/student profile UUID whose submissions to return.
    .PARAMETER Form
        Optional form UUID to return submissions for that form only
        (with -ApplicationId).
    .EXAMPLE
        Get-EnrolHQFormSubmit -Id 'submit-uuid'
    .EXAMPLE
        Get-EnrolHQFormSubmit -ApplicationId $appId -Form $form.id |
            ForEach-Object { "submitted $($_.completed_at) to form $($_.form_id)" }
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'ById', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('SubmitId')]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ByApplication')]
        [string]$ApplicationId,

        [Parameter(ParameterSetName = 'ByApplication')]
        [string]$Form
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            Write-Verbose "Fetching form submit $Id"
            Invoke-EnrolHQRestMethod -Method GET -Endpoint "forms/staff-submits/$Id/"
            return
        }

        Write-Verbose "Fetching application $ApplicationId to resolve its form submits"
        $application = Invoke-EnrolHQRestMethod -Method GET -Endpoint "applications/$ApplicationId/"

        $entries = @()
        if ($application -and $application.PSObject.Properties['custom_form_submits'] -and $application.custom_form_submits) {
            $entries = @($application.custom_form_submits)
        }

        foreach ($entry in $entries) {
            if ($null -eq $entry -or -not $entry.id) { continue }
            if ($PSBoundParameters.ContainsKey('Form') -and $entry.form -ne $Form) { continue }

            Write-Verbose "Fetching form submit $($entry.id) (form $($entry.form))"
            $submit = Invoke-EnrolHQRestMethod -Method GET -Endpoint "forms/staff-submits/$($entry.id)/"
            if ($null -eq $submit) { continue }

            $submit | Add-Member -NotePropertyName 'form_id' -NotePropertyValue $entry.form -Force
            $submit | Add-Member -NotePropertyName 'application_id' -NotePropertyValue $ApplicationId -Force
            $submit
        }
    }
}
