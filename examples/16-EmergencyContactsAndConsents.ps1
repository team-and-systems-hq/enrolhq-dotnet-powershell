<#
.SYNOPSIS
    Pull emergency contacts, medical data, and photo/video consents.
.DESCRIPTION
    These are the two things a list-based export appears to be "missing":

    1. Emergency contacts and medical data live on the application *detail*
       serializer only. Get-EnrolHQApplications returns a lighter summary
       serializer that omits them, so iterating the list endpoint never
       surfaces them no matter which filters you pass. Fetch the detail record
       per application (Get-EnrolHQApplication, optionally with -Section).

    2. Photo/video consents are not application fields at all. They are
       answers on a *custom form* the parent submits, and live in that
       submission's `payload` — reachable via the Get-EnrolHQForm* cmdlets.

    This mirrors the dashboard's "Custom Form Submits" report
    (/dashboard/reports/form-submits/).
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'your-token'

# Replace with a real application/student profile UUID from your instance.
$applicationId = '11111111-1111-1111-1111-111111111111'

# --- 1. Emergency contacts (detail serializer) -------------------------------

Write-Host 'Emergency contacts:'
foreach ($contact in Get-EnrolHQApplication -Id $applicationId -Section EmergencyContacts) {
    Write-Host ("  {0} {1} {2} ({3}) mobile={4} home={5}" -f `
        $contact.title, $contact.first_name, $contact.last_name,
        $contact.relationship_to_student, $contact.mobile_phone, $contact.home_phone)
}

# Medical data and guardians come off the same detail record.
$medical = Get-EnrolHQApplication -Id $applicationId -Section MedicalData
Write-Host "Doctor: $($medical.doctor.name)  Medicare: $($medical.medicare_number)"

# One detail call is enough if you want several of them at once — each
# -Section call makes its own request.
$application = Get-EnrolHQApplication -Id $applicationId
Write-Host "$(@($application.emergency_contacts).Count) contacts, $(@($application.guardians).Count) guardians"

# --- 2. Which forms exist ----------------------------------------------------

Write-Host "`nForms:"
foreach ($form in Get-EnrolHQForms -All -PageSize 100) {
    Write-Host ("  {0,-12} {1} ({2}) {3}" -f $form.kind, $form.title, $form.form_slug, $form.id)
}

# Look a form up by title or slug when you only know its name.
$permissionForm = Get-EnrolHQForm -Name 'medical-update'
if (-not $permissionForm) {
    throw "No form matching 'medical-update' on this instance."
}

# --- 3. Consents for one application -----------------------------------------

# Get-EnrolHQFormSubmit -ApplicationId reads the submit IDs off the application
# detail and fetches each one, because the submits endpoint has no
# per-application filter. Pass -Form to narrow it to a single form.
$submits = Get-EnrolHQFormSubmit -ApplicationId $applicationId -Form $permissionForm.id

foreach ($submit in $submits) {
    Write-Host "`nSubmitted $($submit.completed_at)"

    # -ConsentsOnly returns just the yes/no (RADIO / CHECKBOX) answers.
    foreach ($answer in Get-EnrolHQFormAnswers -SubmitId $submit.id -ConsentsOnly) {
        Write-Host "  $($answer.label): $($answer.value)   [$($answer.name)]"
    }

    # -Submit flattens an already-fetched submit offline (no request) and
    # gives every element, labelled and in form order — useful when you want
    # the free-text and structured answers too.
    foreach ($answer in Get-EnrolHQFormAnswers -Submit $submit) {
        if ($answer.is_profile_backed) {
            # EMERGENCY_CONTACTS / MEDICAL_DATA / PARENT_*_CONTACTS are a
            # snapshot taken when the form was opened. The application detail
            # is authoritative for their current value.
            continue
        }
        Write-Host "  [$($answer.element_type)] $($answer.label): $($answer.value)"
    }
}

# --- 4. Bulk: every submission of a form -------------------------------------

# Filters: -Form (the form UUID — the API param is `form`, not `form_id`),
# -EntryYear, -EntryGrade, -ApplicationStatus, -IsCompleted.
Write-Host "`nCompleted 2027 submissions:"
$bulk = Get-EnrolHQFormSubmits -Form $permissionForm.id -EntryYear 2027 -IsCompleted $true -All -PageSize 100
foreach ($submit in $bulk) {
    $student = $submit.student_profile
    Write-Host "  $($student.first_name) $($student.last_name) $($submit.completed_at)"
}

# Started but never finished — chase these up. A page of 1 carries the total.
$outstanding = Get-EnrolHQFormSubmits -Form $permissionForm.id -IsCompleted $false -PageSize 1
Write-Host "$($outstanding.Count) incomplete submissions"

# Careful: these summary records carry `student_profile` but NOT the submit's
# own id, so you cannot pass them to Get-EnrolHQFormSubmit -Id.
# Get-EnrolHQFormAnswers -Form walks student_profile.id back through the
# application detail for you (one request per application) and attaches
# `student_profile`, `submit_id`, `form_id` and `completed_at` to each answer.
Write-Host "`nConsents per student:"
$answers = Get-EnrolHQFormAnswers -Form $permissionForm.id -EntryYear 2027 -IsCompleted $true -ConsentsOnly
foreach ($group in $answers | Group-Object submit_id) {
    $student  = $group.Group[0].student_profile
    $consents = ($group.Group | ForEach-Object { "$($_.label)=$($_.value)" }) -join ', '
    Write-Host "  $($student.first_name) $($student.last_name): $consents"
}

# --- 5. Bulk export (fastest path for a warehouse load) ----------------------

# Get-EnrolHQFormAnswers -Form costs one request per application. The CSV
# export flattens student details, emergency contacts, medical data and every
# consent answer into one row per submission in a single request — prefer it
# for a warehouse load.
$csv  = Export-EnrolHQFormSubmits -DestinationPath './consents.csv' -Form $permissionForm.id -IsCompleted $true
$rows = Import-Csv $csv.FullName
$columns = if ($rows.Count -gt 0) { $rows[0].PSObject.Properties.Name.Count } else { 0 }
Write-Host "`nExported $($rows.Count) rows, $columns columns to $($csv.FullName)"
foreach ($row in $rows) {
    Write-Host "  $($row.'profile.first_name') $($row.'payload.group_3_social_media')"
}

Disconnect-EnrolHQ
