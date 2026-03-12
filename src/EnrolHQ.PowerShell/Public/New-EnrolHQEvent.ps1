function New-EnrolHQEvent {
    <#
    .SYNOPSIS
        Creates a new EnrolHQ event.
    .PARAMETER Data
        Hashtable containing event data (name, kind, campus, sessions, etc.).
    .EXAMPLE
        New-EnrolHQEvent -Data @{
            name = 'Open Day 2026'
            description = 'Annual school open day'
            is_enabled = $true
        }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable]$Data
    )

    $description = $Data['name'] ?? 'New event'
    if ($PSCmdlet.ShouldProcess($description, 'Create EnrolHQ Event')) {
        Invoke-EnrolHQRestMethod -Method POST -Endpoint 'staff-events/' -Body $Data
    }
}
