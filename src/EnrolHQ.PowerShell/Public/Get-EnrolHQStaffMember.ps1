function Get-EnrolHQStaffMember {
    <#
    .SYNOPSIS
        Gets a single EnrolHQ staff member by ID.
    .PARAMETER Id
        The staff member ID.
    .EXAMPLE
        Get-EnrolHQStaffMember -Id '456'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('StaffId')]
        [string]$Id
    )

    process {
        Invoke-EnrolHQRestMethod -Method GET -Endpoint "staff/$Id/"
    }
}
