function Set-EnrolHQLead {
    <#
    .SYNOPSIS
        Updates an existing EnrolHQ lead.
    .DESCRIPTION
        Performs a full PUT update on a lead. WARNING: This is a full
        replacement - omitted fields may be reset to defaults. The recommended
        pattern is: Get -> Modify -> Set.
    .PARAMETER Id
        The lead UUID.
    .PARAMETER Data
        The complete lead object (hashtable or the object returned by
        Get-EnrolHQLead).
    .EXAMPLE
        # Get -> Modify -> Set pattern
        $lead = Get-EnrolHQLead -Id $id
        $lead.student.comment = 'Followed up by phone'
        Set-EnrolHQLead -Id $id -Data $lead
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Id,

        [Parameter(Mandatory, Position = 1)]
        [object]$Data
    )

    if ($PSCmdlet.ShouldProcess($Id, 'Update EnrolHQ Lead')) {
        Write-Verbose 'Set-EnrolHQLead uses PUT (full replacement). Omitted fields may be reset.'
        Invoke-EnrolHQRestMethod -Method PUT -Endpoint "leads/$Id/" -Body $Data
    }
}
