function Remove-EnrolHQEvent {
    <#
    .SYNOPSIS
        Deletes an EnrolHQ event.
    .PARAMETER Id
        The event ID to delete.
    .EXAMPLE
        Remove-EnrolHQEvent -Id '123'
    .EXAMPLE
        Remove-EnrolHQEvent -Id '123' -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('EventId')]
        [string]$Id
    )

    process {
        if ($PSCmdlet.ShouldProcess($Id, 'Delete EnrolHQ Event')) {
            Invoke-EnrolHQRestMethod -Method DELETE -Endpoint "staff-events/$Id/"
        }
    }
}
