function Remove-EnrolHQDocument {
    <#
    .SYNOPSIS
        Deletes a document from EnrolHQ.
    .PARAMETER Id
        The document ID to delete.
    .EXAMPLE
        Remove-EnrolHQDocument -Id 'doc-uuid-123'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DocumentId')]
        [string]$Id
    )

    process {
        if ($PSCmdlet.ShouldProcess($Id, 'Delete EnrolHQ Document')) {
            Invoke-EnrolHQRestMethod -Method DELETE -Endpoint "application-documents/$Id/"
        }
    }
}
