function Set-EnrolHQFormSubmit {
    <#
    .SYNOPSIS
        Overwrites a form submission's payload (staff edit).
    .DESCRIPTION
        Sends PUT forms/staff-submits/{id}/ with `{ payload = ... }`.

        WARNING: This replaces the WHOLE payload. Read it first with
        Get-EnrolHQFormSubmit, modify `.payload`, then write it back.
    .PARAMETER Id
        The submit UUID.
    .PARAMETER Payload
        The complete payload object (hashtable or the `.payload` of a fetched
        submit).
    .EXAMPLE
        $submit = Get-EnrolHQFormSubmit -Id $submitId
        $submit.payload.group_3_social_media = 'No'
        Set-EnrolHQFormSubmit -Id $submitId -Payload $submit.payload
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('SubmitId')]
        [string]$Id,

        [Parameter(Mandatory, Position = 1)]
        [object]$Payload
    )

    if ($PSCmdlet.ShouldProcess($Id, 'Update EnrolHQ Form Submit payload')) {
        Write-Verbose 'Set-EnrolHQFormSubmit replaces the whole payload (PUT).'
        Invoke-EnrolHQRestMethod -Method PUT -Endpoint "forms/staff-submits/$Id/" -Body @{ payload = $Payload }
    }
}
