function Unlock-EnrolHQFormSubmit {
    <#
    .SYNOPSIS
        Re-opens a completed form submission so the parent can edit it again.
    .DESCRIPTION
        Sends POST forms/staff-submits/{id}/re_open/ (the API action is
        `re_open`). The submission's `completed_at` is cleared and the parent
        can amend and resubmit the form.
    .PARAMETER Id
        The submit UUID.
    .EXAMPLE
        Unlock-EnrolHQFormSubmit -Id $submitId
    .EXAMPLE
        Get-EnrolHQFormSubmit -ApplicationId $appId -Form $form.id | Unlock-EnrolHQFormSubmit
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('SubmitId')]
        [string]$Id
    )

    process {
        if ($PSCmdlet.ShouldProcess($Id, 'Re-open EnrolHQ Form Submit')) {
            Invoke-EnrolHQRestMethod -Method POST -Endpoint "forms/staff-submits/$Id/re_open/"
        }
    }
}
