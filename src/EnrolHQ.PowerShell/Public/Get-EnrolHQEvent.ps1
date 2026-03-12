function Get-EnrolHQEvent {
    <#
    .SYNOPSIS
        Gets a single EnrolHQ event by ID.
    .PARAMETER Id
        The event ID.
    .EXAMPLE
        Get-EnrolHQEvent -Id '123'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('EventId')]
        [string]$Id
    )

    process {
        Invoke-EnrolHQRestMethod -Method GET -Endpoint "staff-events/$Id/"
    }
}
