function Get-EnrolHQApplication {
    <#
    .SYNOPSIS
        Gets a single EnrolHQ application by ID.
    .DESCRIPTION
        Retrieves the full detail for a single student application, including
        all parent data, medical information, documents, progress, and offers.
    .PARAMETER Id
        The application/student profile UUID.
    .EXAMPLE
        Get-EnrolHQApplication -Id 'abc12345-def6-7890-abcd-ef1234567890'
    .EXAMPLE
        'abc12345-def6-7890-abcd-ef1234567890' | Get-EnrolHQApplication
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ApplicationId', 'StudentProfileId')]
        [string]$Id
    )

    process {
        Write-Verbose "Fetching application $Id"
        Invoke-EnrolHQRestMethod -Method GET -Endpoint "applications/$Id/"
    }
}
