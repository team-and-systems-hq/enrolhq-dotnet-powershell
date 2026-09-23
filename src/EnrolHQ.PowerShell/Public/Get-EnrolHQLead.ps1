function Get-EnrolHQLead {
    <#
    .SYNOPSIS
        Gets a single EnrolHQ lead by ID.
    .DESCRIPTION
        Retrieves the full detail for a single lead, including the nested
        `student`, `residential_address`, `reference` and `student_profile`
        fields.
    .PARAMETER Id
        The lead UUID.
    .EXAMPLE
        Get-EnrolHQLead -Id 'abc12345-def6-7890-abcd-ef1234567890'
    .EXAMPLE
        (Get-EnrolHQLeads -PageSize 5).Results | Get-EnrolHQLead
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('LeadId')]
        [string]$Id
    )

    process {
        Write-Verbose "Fetching lead $Id"
        Invoke-EnrolHQRestMethod -Method GET -Endpoint "leads/$Id/"
    }
}
