function New-EnrolHQLead {
    <#
    .SYNOPSIS
        Creates a new EnrolHQ lead (pre-enquiry contact).
    .DESCRIPTION
        Creates a lead on the v2 API (POST leads/). A lead captures a contact
        (parent) and optionally a prospective student before a full
        application exists.

        Payload shape (hashtable keys):
          email, title, first_name, last_name, mobile_phone, home_phone,
          business_phone           - contact details
          reference                - lead reference UUID identifying which
                                     form/source the lead came from
                                     (see Get-EnrolHQLeadReferences)
          student                  - nested: first_name, last_name, dob,
                                     entry_grade, entry_year, campus, comment,
                                     questions, questions_other
          residential_address      - nested: apartment, street_address, city,
                                     suburb, state, postcode, country
          student_profile          - a student profile UUID. Set this to link
                                     the lead to an existing application;
                                     $null creates a standalone lead.
          how_hear, how_hear_other - marketing attribution

        Migrating from the legacy v1 Zapier integration: the old Zap POSTed to
        /api/v1/leads/ with X-API-TOKEN / X-ENROLHQ-DOMAIN headers. This cmdlet
        replaces it - authentication is handled by Connect-EnrolHQ, and the
        payload fields map 1:1 (email, title, first_name, last_name,
        mobile_phone, reference, student, residential_address). The v1-only
        flag `is_lead_submitted_system_event_should_be_dispatched` is not part
        of the v2 payload - drop it.
    .PARAMETER Data
        A hashtable (or object) containing the lead data.
    .EXAMPLE
        New-EnrolHQLead -Data @{
            email        = 'jane.doe@example.com'
            title        = 'Mrs'
            first_name   = 'Jane'
            last_name    = 'Doe'
            mobile_phone = '+61400000000'
            reference    = $reference.id
            student      = @{
                first_name = 'Sam'; last_name = 'Doe'; dob = '2015-03-15'
                entry_grade = 7; entry_year = 2028; comment = ''
                questions = @(); questions_other = ''
            }
            residential_address = @{
                apartment = ''; street_address = '1 Example St'; city = ''
                suburb = 'ULTIMO'; state = 'NSW'; postcode = '2007'; country = $null
            }
            how_hear        = @()
            how_hear_other  = ''
            student_profile = $null
        }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [object]$Data
    )

    $email = $null
    if ($Data -is [System.Collections.IDictionary]) { $email = $Data['email'] }
    elseif ($Data.PSObject.Properties['email']) { $email = $Data.email }
    $description = if ($email) { [string]$email } else { 'New lead' }

    if ($PSCmdlet.ShouldProcess($description, 'Create EnrolHQ Lead')) {
        Invoke-EnrolHQRestMethod -Method POST -Endpoint 'leads/' -Body $Data
    }
}
