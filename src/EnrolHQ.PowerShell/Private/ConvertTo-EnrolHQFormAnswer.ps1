function ConvertTo-EnrolHQFormAnswer {
    <#
    .SYNOPSIS
        Flattens a form submission into labelled answer records.
    .DESCRIPTION
        Joins a submit's raw `payload` against its `form_schema` so each answer
        carries the question text a parent actually saw, instead of an opaque
        key like `group_3_social_media`.

        A submit stores answers in two places:
          payload         - answers to the form's own questions (radio,
                            checkbox, text, signature, ...). Consent /
                            permission answers live here.
          initial_payload - the profile data pre-filled into the form when it
                            was opened, plus blank slots for the form's own
                            questions.
        Overlaying payload on initial_payload gives the final state.

        Emits one object per answerable element, in form order. Layout-only
        elements (HTML, HEADER, DIVIDER, IMAGE) are skipped. Elements flagged
        `is_profile_backed` (EMERGENCY_CONTACTS, MEDICAL_DATA,
        PARENT_1_CONTACTS, PARENT_2_CONTACTS, GUARDIAN_CONTACTS, DOCUMENTS) are
        copies of profile data taken when the form was opened - read the
        application detail for their current value.
    .PARAMETER Submit
        A submit object as returned by forms/staff-submits/{id}/ (must carry
        `form_schema`; `payload` / `initial_payload` may be null).
    .NOTES
        Private function used by Get-EnrolHQFormAnswers. No API calls.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object]$Submit
    )

    $contentElements = @('HTML', 'HEADER', 'DIVIDER', 'IMAGE')
    $profileBackedElements = @(
        'EMERGENCY_CONTACTS', 'MEDICAL_DATA', 'PARENT_1_CONTACTS',
        'PARENT_2_CONTACTS', 'GUARDIAN_CONTACTS', 'DOCUMENTS'
    )

    if ($null -eq $Submit) { return }

    # Merge initial_payload then payload into one name -> value map. Each may
    # be $null, a PSCustomObject (from ConvertFrom-Json) or a hashtable.
    $values = [ordered]@{}
    foreach ($source in @($Submit.initial_payload, $Submit.payload)) {
        if ($null -eq $source) { continue }
        if ($source -is [System.Collections.IDictionary]) {
            foreach ($key in $source.Keys) { $values[[string]$key] = $source[$key] }
        }
        else {
            foreach ($prop in $source.PSObject.Properties) { $values[$prop.Name] = $prop.Value }
        }
    }

    $schema = $null
    if ($Submit.form_schema) { $schema = $Submit.form_schema.schema }
    if (-not $schema) { return }

    foreach ($section in @($schema)) {
        if ($null -eq $section) { continue }
        $sectionTitle = if ($section.title) { [string]$section.title } else { '' }

        foreach ($element in @($section.elements)) {
            if ($null -eq $element) { continue }
            $elementType = if ($element.element_type) { [string]$element.element_type } else { '' }
            if ($elementType -in $contentElements) { continue }

            $name = $element.name
            $value = $null
            if ($null -ne $name -and $values.Contains([string]$name)) {
                $value = $values[[string]$name]
            }

            [PSCustomObject]@{
                PSTypeName        = 'EnrolHQ.FormAnswer'
                section           = $sectionTitle
                name              = $name
                label             = ([string]$element.label).Trim()
                element_type      = $elementType
                value             = $value
                is_profile_backed = ($elementType -in $profileBackedElements)
            }
        }
    }
}
