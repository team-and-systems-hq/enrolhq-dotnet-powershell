function Get-EnrolHQCmsSettings {
    <#
    .SYNOPSIS
        Retrieves the school's CMS / form configuration settings.
    .DESCRIPTION
        Reads the read-only cms-settings/ endpoint, which returns a single
        configuration object covering enquiry and event-booking copy, form
        labels, terms & conditions, parent-dashboard visibility flags, and the
        school policy agreement items shown to applicants.
    .PARAMETER QueryParameters
        Optional query parameters to pass to the endpoint.
    .EXAMPLE
        Get-EnrolHQCmsSettings

        Get the full CMS settings object.
    .EXAMPLE
        (Get-EnrolHQCmsSettings).event_booking.page_header

        Read a nested setting.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$QueryParameters = @{}
    )

    Write-Verbose 'Fetching CMS settings from cms-settings/'

    Invoke-EnrolHQRestMethod -Method GET -Endpoint 'cms-settings/' -QueryParameters $QueryParameters
}
