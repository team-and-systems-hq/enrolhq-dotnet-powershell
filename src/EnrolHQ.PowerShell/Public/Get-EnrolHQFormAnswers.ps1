function Get-EnrolHQFormAnswers {
    <#
    .SYNOPSIS
        Returns a form submission's answers flattened and labelled.
    .DESCRIPTION
        Joins a submit's raw `payload` against the form's schema so each
        answer carries the question text the parent actually saw, instead of
        an opaque key like `group_3_social_media`.

        Emits one object per answerable element, in form order:
          section, name, label, element_type, value, is_profile_backed

        Layout-only elements (HTML blocks, dividers) are skipped. Elements
        flagged `is_profile_backed` (EMERGENCY_CONTACTS, MEDICAL_DATA,
        PARENT_*_CONTACTS, GUARDIAN_CONTACTS, DOCUMENTS) are copies of profile
        data taken when the form was opened - read Get-EnrolHQApplication for
        their current value.

        `value` is not always a scalar: EMERGENCY_CONTACTS is a list of
        contacts, MEDICAL_DATA an object, checkbox groups a list of selected
        options, and a DOCUMENTS element is a document *group* whose files
        live under its `documents` property.

        Four ways to select submissions:
          -SubmitId       one submission (fetched)
          -Submit         one already-fetched submission (no request)
          -ApplicationId  every submission for one application (optionally
                          one form); answers gain submit_id, form_id,
                          application_id, completed_at
          -Form           every completed/started submission of a form in
                          bulk; answers also gain student_profile. This costs
                          one request per matching application, because the
                          submits list omits the submit id. For a large
                          export prefer Export-EnrolHQFormSubmits.

        Bulk-mode filters (-EntryYear, -EntryGrade, -ApplicationStatus,
        -IsCompleted) choose WHICH APPLICATIONS are visited; every submission
        of the form for each of those applications is then returned (the
        same behaviour as the Python SDK's iter_answers). If a parent has both
        a completed and an unfinished submission, both come back - check
        `completed_at` on each answer when you need only completed ones.
    .PARAMETER SubmitId
        A submit UUID to fetch and flatten.
    .PARAMETER Submit
        A submit object (from Get-EnrolHQFormSubmit) to flatten offline. A
        plain string piped in is treated as a submit id and fetched.
    .PARAMETER ApplicationId
        An application/student profile UUID whose submissions to flatten.
    .PARAMETER Form
        A form UUID. Optional with -ApplicationId (narrows to that form);
        required for bulk mode.
    .PARAMETER EntryYear
        Bulk mode: filter submissions by entry year.
    .PARAMETER EntryGrade
        Bulk mode: filter submissions by entry grade.
    .PARAMETER ApplicationStatus
        Bulk mode: filter submissions by application status code(s).
    .PARAMETER IsCompleted
        Bulk mode: $true for submitted, $false for started but not finished.
    .PARAMETER PageSize
        Bulk mode: records fetched per request when listing submits. Default: 100.
    .PARAMETER ConsentsOnly
        Keep only the yes/no permission answers (RADIO, CHECKBOX and
        CHECKBOX_GROUP elements). A permission/consent form models each
        permission as one of these.
    .EXAMPLE
        Get-EnrolHQFormAnswers -SubmitId $submitId -ConsentsOnly |
            Select-Object label, value

        Read the consent answers on one submission.
    .EXAMPLE
        Get-EnrolHQFormSubmit -ApplicationId $appId | Get-EnrolHQFormAnswers
    .EXAMPLE
        Get-EnrolHQFormAnswers -ApplicationId $appId -Form $form.id |
            Where-Object { -not $_.is_profile_backed } |
            Select-Object section, label, value
    .EXAMPLE
        Get-EnrolHQFormAnswers -Form $form.id -EntryYear 2027 -IsCompleted $true -ConsentsOnly |
            Select-Object @{n='student';e={$_.student_profile.last_name}}, label, value |
            Export-Csv consents.csv
    #>
    [CmdletBinding(DefaultParameterSetName = 'BySubmitId')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'BySubmitId')]
        [string]$SubmitId,

        [Parameter(Mandatory, ParameterSetName = 'BySubmit', ValueFromPipeline)]
        [object]$Submit,

        [Parameter(Mandatory, ParameterSetName = 'ByApplication')]
        [string]$ApplicationId,

        [Parameter(ParameterSetName = 'ByApplication')]
        [Parameter(Mandatory, ParameterSetName = 'ByForm')]
        [string]$Form,

        [Parameter(ParameterSetName = 'ByForm')]
        [int]$EntryYear,

        [Parameter(ParameterSetName = 'ByForm')]
        [int]$EntryGrade,

        [Parameter(ParameterSetName = 'ByForm')]
        [int[]]$ApplicationStatus,

        [Parameter(ParameterSetName = 'ByForm')]
        [bool]$IsCompleted,

        [Parameter(ParameterSetName = 'ByForm')]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 100,

        [Parameter()]
        [switch]$ConsentsOnly
    )

    begin {
        $consentElements = @('RADIO', 'CHECKBOX', 'CHECKBOX_GROUP')

        # Flatten one submit, optionally stamping extra context properties
        # (submit_id, form_id, application_id, completed_at, student_profile)
        # onto every answer so the output stays one-object-per-answer.
        function Expand-Submit {
            param([object]$SubmitObject, [hashtable]$Context = @{})
            foreach ($answer in @(ConvertTo-EnrolHQFormAnswer -Submit $SubmitObject)) {
                if ($null -eq $answer) { continue }
                if ($ConsentsOnly -and $answer.element_type -notin $consentElements) { continue }
                foreach ($key in $Context.Keys) {
                    $answer | Add-Member -NotePropertyName $key -NotePropertyValue $Context[$key] -Force
                }
                $answer
            }
        }

        function Expand-Application {
            param([string]$AppId, [string]$FormId, [hashtable]$Extra = @{})
            $submitParams = @{ ApplicationId = $AppId }
            if ($FormId) { $submitParams['Form'] = $FormId }
            foreach ($submit in @(Get-EnrolHQFormSubmit @submitParams)) {
                if ($null -eq $submit) { continue }
                $context = @{
                    submit_id      = $submit.id
                    form_id        = $submit.form_id
                    application_id = $AppId
                    completed_at   = $submit.completed_at
                } + $Extra
                Expand-Submit -SubmitObject $submit -Context $context
            }
        }
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'BySubmitId' {
                Write-Verbose "Fetching form submit $SubmitId"
                $fetched = Invoke-EnrolHQRestMethod -Method GET -Endpoint "forms/staff-submits/$SubmitId/"
                Expand-Submit -SubmitObject $fetched
            }
            'BySubmit' {
                if ($Submit -is [string]) {
                    # A bare id was piped in - fetch it rather than silently
                    # producing nothing.
                    Write-Verbose "Fetching form submit $Submit"
                    $fetched = Invoke-EnrolHQRestMethod -Method GET -Endpoint "forms/staff-submits/$Submit/"
                    Expand-Submit -SubmitObject $fetched
                }
                else {
                    Expand-Submit -SubmitObject $Submit
                }
            }
            'ByApplication' {
                $formId = if ($PSBoundParameters.ContainsKey('Form')) { $Form } else { $null }
                Expand-Application -AppId $ApplicationId -FormId $formId
            }
            'ByForm' {
                $listParams = @{ Form = $Form; PageSize = $PageSize; All = $true }
                if ($PSBoundParameters.ContainsKey('EntryYear'))         { $listParams['EntryYear'] = $EntryYear }
                if ($PSBoundParameters.ContainsKey('EntryGrade'))        { $listParams['EntryGrade'] = $EntryGrade }
                if ($PSBoundParameters.ContainsKey('ApplicationStatus')) { $listParams['ApplicationStatus'] = $ApplicationStatus }
                if ($PSBoundParameters.ContainsKey('IsCompleted'))       { $listParams['IsCompleted'] = $IsCompleted }

                Write-Verbose "Listing submits for form $Form (one detail request per application follows)"
                $seen = [System.Collections.Generic.HashSet[string]]::new()

                foreach ($summary in @(Get-EnrolHQFormSubmits @listParams)) {
                    $profile = $summary.student_profile
                    $profileId = if ($profile) { [string]$profile.id } else { $null }
                    if (-not $profileId -or -not $seen.Add($profileId)) { continue }

                    Expand-Application -AppId $profileId -FormId $Form -Extra @{ student_profile = $profile }
                }
            }
        }
    }
}
