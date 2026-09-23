<#
.SYNOPSIS
    Work with leads (pre-enquiry contacts) and lead references.
.DESCRIPTION
    A lead captures a contact (usually a parent) and optionally a prospective
    student before a full application exists — e.g. from a "keep me updated"
    website form. This example lists leads, reads lead references, creates a
    lead, and updates one.

    All endpoints are on the v2 API: leads/, leads/<id>/ and lead-references/.
    Get-EnrolHQLeads / Get-EnrolHQLead / New-EnrolHQLead / Set-EnrolHQLead
    replace the legacy v1 Zapier POST /api/v1/leads/ integration.

    WARNING: The create/update sections write real data to your instance.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'your-token'

# --- Lead references ---------------------------------------------------------
# A lead reference identifies which form/source a lead came from. Use its
# `id` as the `reference` field when creating a lead.

$references = Get-EnrolHQLeadReferences
Write-Host "Lead references ($($references.Count)):"
foreach ($ref in $references) {
    Write-Host "  $($ref.name) ($($ref.slug)): $($ref.id)"
}

# Create a lead reference. There is no dedicated write endpoint — the cmdlet
# round-trips the school/ settings object and returns the new record with its
# server-assigned id. Creating an existing slug throws, so reuse the reference
# if this example has run before.
$refSlug   = 'sdk-example-reference'
$reference = $references | Where-Object slug -eq $refSlug | Select-Object -First 1
if (-not $reference) {
    $reference = New-EnrolHQLeadReference -Name 'SDK Example Reference' -Slug $refSlug
}
Write-Host "Using reference: $($reference.name) ($($reference.id))"

# --- List leads --------------------------------------------------------------

# Every lead (auto-paginates through all pages).
$leads = Get-EnrolHQLeads -All -PageSize 100
Write-Host "`nLeads ($($leads.Count)):"
foreach ($lead in $leads) {
    $entryYear = if ($lead.student) { $lead.student.entry_year } else { $null }
    Write-Host "  $($lead.email) $($lead.first_name) $($lead.last_name) $entryYear"
}

# Filter: only leads not yet linked to a student profile. A single page carries
# the total in .Count, so this is the cheapest way to count.
$page = Get-EnrolHQLeads -HasStudentProfile $false -PageSize 25
Write-Host "`n$($page.Count) leads without a linked profile"

# --- Get a single lead -------------------------------------------------------

if ($page.Results.Count -gt 0) {
    $detail = Get-EnrolHQLead -Id $page.Results[0].id
    Write-Host "First unlinked lead: $($detail.email) reference=$($detail.reference) status=$($detail.lead_status)"
}

# --- Create a lead -----------------------------------------------------------

$newLead = New-EnrolHQLead -Data @{
    email               = 'jane.doe@example.com'
    title               = 'Mrs'
    first_name          = 'Jane'
    last_name           = 'Doe'
    mobile_phone        = '+61400000000'
    reference           = $reference.id
    student             = @{
        first_name      = 'Sam'
        last_name       = 'Doe'
        dob             = '2015-03-15'
        entry_grade     = 7
        entry_year      = 2028
        comment         = 'Interested in the music program'
        questions       = @()
        questions_other = ''
    }
    residential_address = @{
        apartment      = ''
        street_address = '1 Example St'
        city           = ''
        suburb         = 'ULTIMO'
        state          = 'NSW'
        postcode       = '2007'
        country        = $null
    }
    how_hear            = @()
    how_hear_other      = ''
    # Set this to a student profile UUID to link the lead to an existing
    # application; $null creates a standalone lead.
    student_profile     = $null
}
Write-Host "`nCreated lead: $($newLead.id)"

# --- Update a lead -----------------------------------------------------------
# Updates use PUT (full replacement): Get -> modify -> Set.

$lead = Get-EnrolHQLead -Id $newLead.id
$lead.student.comment = 'Followed up by phone'
$updated = Set-EnrolHQLead -Id $lead.id -Data $lead
Write-Host "Updated: $($updated.student.comment)"

Disconnect-EnrolHQ
