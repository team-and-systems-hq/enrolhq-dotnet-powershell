function Get-EnrolHQMetafields {
    <#
    .SYNOPSIS
        Retrieves per-model field configuration ("metafields").
    .DESCRIPTION
        Reads the read-only metafields/ endpoint, which describes how each field
        on each model (student, parent, doctor, guardian, emergency_contact,
        medical_data, ...) is configured. For every field there is a `label`
        plus `enabled` and `mandatory` maps keyed by scope:

          enr   = enrolment form      evt   = event booking
          eoi   = GPA / EOI form      cust  = custom form
          enq   = enquiry form        admin = admin view (enabled only)

        The endpoint returns `field_settings` (the school's configured fields)
        and `default_field_settings` (the platform defaults).
    .PARAMETER Section
        Which part of the response to return:
          All                  - the full object (default)
          FieldSettings        - only the school's configured field_settings map
          DefaultFieldSettings - only the platform default_field_settings map
    .PARAMETER QueryParameters
        Optional query parameters to pass to the endpoint.
    .EXAMPLE
        Get-EnrolHQMetafields

        Get the full metafields object.
    .EXAMPLE
        Get-EnrolHQMetafields -Section FieldSettings

        Get only the configured field_settings map.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('All', 'FieldSettings', 'DefaultFieldSettings')]
        [string]$Section = 'All',

        [Parameter()]
        [hashtable]$QueryParameters = @{}
    )

    Write-Verbose 'Fetching metafields from metafields/'

    $response = Invoke-EnrolHQRestMethod -Method GET -Endpoint 'metafields/' -QueryParameters $QueryParameters

    switch ($Section) {
        'FieldSettings'        { $response.field_settings }
        'DefaultFieldSettings' { $response.default_field_settings }
        default                { $response }
    }
}
