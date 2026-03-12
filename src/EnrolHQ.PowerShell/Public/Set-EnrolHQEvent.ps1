function Set-EnrolHQEvent {
    <#
    .SYNOPSIS
        Updates an existing EnrolHQ event.
    .PARAMETER Id
        The event ID.
    .PARAMETER Data
        Hashtable containing the updated event data.
    .EXAMPLE
        Set-EnrolHQEvent -Id '123' -Data @{ name = 'Updated Open Day'; is_enabled = $false }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Id,

        [Parameter(Mandatory, Position = 1)]
        [hashtable]$Data
    )

    if ($PSCmdlet.ShouldProcess($Id, 'Update EnrolHQ Event')) {
        Invoke-EnrolHQRestMethod -Method PUT -Endpoint "staff-events/$Id/" -Body $Data
    }
}
