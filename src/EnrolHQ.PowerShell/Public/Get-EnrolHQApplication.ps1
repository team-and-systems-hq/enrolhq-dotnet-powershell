function Get-EnrolHQApplication {
    <#
    .SYNOPSIS
        Gets a single EnrolHQ application by ID.
    .DESCRIPTION
        Retrieves the full detail for a single student application, including
        all parent data, medical information, documents, progress, and offers.

        Emergency contacts, medical data and guardians exist on this *detail*
        serializer only. Get-EnrolHQApplications returns a lighter summary
        serializer that omits them, which is why they appear "missing" from
        list-based exports. Use -Section to pull just one of those nested
        blocks.
    .PARAMETER Id
        The application/student profile UUID.
    .PARAMETER Section
        Which part of the detail to return:
          All               - the full application detail (default)
          EmergencyContacts - the `emergency_contacts` list (id, title,
                              first_name, last_name, relationship_to_student,
                              home_phone, mobile_phone, business_phone,
                              external_id, updated_at)
          MedicalData       - the `medical_data` object (doctor, medicare,
                              conditions)
          Guardians         - the `guardians` list
    .EXAMPLE
        Get-EnrolHQApplication -Id 'abc12345-def6-7890-abcd-ef1234567890'
    .EXAMPLE
        'abc12345-def6-7890-abcd-ef1234567890' | Get-EnrolHQApplication
    .EXAMPLE
        Get-EnrolHQApplication -Id $id -Section EmergencyContacts |
            Select-Object first_name, last_name, relationship_to_student, mobile_phone

        List an application's emergency contacts (not available from
        Get-EnrolHQApplications).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ApplicationId', 'StudentProfileId')]
        [string]$Id,

        [Parameter()]
        [ValidateSet('All', 'EmergencyContacts', 'MedicalData', 'Guardians')]
        [string]$Section = 'All'
    )

    process {
        Write-Verbose "Fetching application $Id"
        $app = Invoke-EnrolHQRestMethod -Method GET -Endpoint "applications/$Id/"

        switch ($Section) {
            'EmergencyContacts' {
                if ($app.emergency_contacts) { @($app.emergency_contacts) } else { @() }
            }
            'MedicalData' {
                if ($app.medical_data) { $app.medical_data } else { [PSCustomObject]@{} }
            }
            'Guardians' {
                if ($app.guardians) { @($app.guardians) } else { @() }
            }
            default { $app }
        }
    }
}
