<#
.SYNOPSIS
    Discover custom forms, pick one, and read a student's answers to it.
.DESCRIPTION
    Nothing here is hardcoded — every id is discovered at runtime:

        list the custom forms
          -> pick one
            -> find a student who submitted it
              -> read that student's answers

    Run it as-is against any instance. Set $FormName to a form's title or slug
    to target a specific form instead of the busiest one.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'your-token'

# Set to a form title or slug (e.g. 'photo-permission') to pick that form.
# Leave as $null to use whichever custom form has the most submissions.
$FormName = $null

# --- 1. Which custom forms exist? --------------------------------------------

# Get-EnrolHQForms returns every form including the built-in stubs (enquiry,
# event booking, ...). kind -eq 'CUSTOM' narrows it to the school's own forms.
$forms = Get-EnrolHQForms -All -PageSize 100 | Where-Object kind -eq 'CUSTOM'

if (-not $forms) {
    throw 'This instance has no custom forms.'
}

# A page of 1 is the cheapest way to get a count — the response carries the
# total in .Count. Count once and reuse; the API is rate limited, so don't
# re-query per form in the selection step below.
$completedCounts = @{}
foreach ($form in $forms) {
    $completedCounts[$form.id] = (Get-EnrolHQFormSubmits -Form $form.id -IsCompleted $true -PageSize 1).Count
}

Write-Host "$($forms.Count) custom forms:`n"
foreach ($form in $forms) {
    Write-Host "  $($form.title)"
    Write-Host "    slug=$($form.form_slug)  completed submissions=$($completedCounts[$form.id])"
}

# --- 2. Choose one -----------------------------------------------------------

if ($FormName) {
    $form = Get-EnrolHQForm -Name $FormName
    if (-not $form) {
        throw "No form matching '$FormName'."
    }
}
else {
    # Default to the busiest form, so the example has something to show on
    # any instance.
    $form = $forms | Sort-Object { $completedCounts[$_.id] } -Descending | Select-Object -First 1
    if (-not $completedCounts[$form.id]) {
        throw 'No custom form on this instance has a completed submission.'
    }
}

Write-Host "`nUsing form: $($form.title) ($($form.form_slug))"

# --- 3. Find a student who submitted it --------------------------------------

# Submits list records carry `student_profile` but NOT the submit's own id,
# so take the profile id here and resolve the submit in the next step.
$page = Get-EnrolHQFormSubmits -Form $form.id -IsCompleted $true -PageSize 1
if ($page.Results.Count -eq 0) {
    throw "No completed submissions for '$($form.title)'."
}

$student   = $page.Results[0].student_profile
$profileId = $student.id
Write-Host "Student: $($student.first_name) $($student.last_name) (Year $($student.entry_grade), $($student.entry_year)) $profileId"

# --- 4. Read that student's answers ------------------------------------------

# Get-EnrolHQFormAnswers -ApplicationId resolves the submit ids via the
# application detail, then labels each answer using the form's own schema.
# One answer object per element, tagged with submit_id / completed_at.
$answers = Get-EnrolHQFormAnswers -ApplicationId $profileId -Form $form.id

foreach ($record in $answers | Group-Object submit_id) {
    Write-Host "`nSubmitted $($record.Group[0].completed_at)"
    $section = $null
    foreach ($answer in $record.Group) {
        if ($answer.section -ne $section) {
            $section = $answer.section
            Write-Host "`n  $section"
        }

        $label = if ($answer.label) { $answer.label } else { $answer.name }

        if ($answer.is_profile_backed) {
            # EMERGENCY_CONTACTS / MEDICAL_DATA / PARENT_*_CONTACTS / DOCUMENTS
            # are a snapshot taken when the form was opened. The application
            # detail holds the authoritative current value.
            $value = $answer.value
            $summary = if ($value -is [array]) {
                "$($value.Count) record(s)"
            }
            elseif ($value -is [pscustomobject] -and $value.PSObject.Properties['documents']) {
                # A DOCUMENTS element is a document *group*, not a list — its
                # files are under "documents".
                "$(@($value.documents).Count) file(s)"
            }
            elseif ($value -is [pscustomobject]) {
                "$($value.PSObject.Properties.Name.Count) field(s)"
            }
            else {
                'no data'
            }
            Write-Host "    [$($answer.element_type)] ${label}: $summary — see Get-EnrolHQApplication for current values"
            continue
        }

        Write-Host "    ${label}: $($answer.value)"
    }
}

# --- 5. The same answers, straight from the profile id -----------------------

# One call, if you already know the student profile you care about — every
# form they have submitted, not just the one chosen above.
foreach ($record in Get-EnrolHQFormAnswers -ApplicationId $profileId | Group-Object submit_id) {
    $answered = $record.Group | Where-Object { -not $_.is_profile_backed }
    Write-Host "`n$($record.Group[0].form_id): $(@($answered).Count) answers ($($record.Group[0].completed_at))"
}

Disconnect-EnrolHQ
