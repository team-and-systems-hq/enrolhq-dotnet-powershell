function Set-EnrolHQApplication {
    <#
    .SYNOPSIS
        Updates an existing EnrolHQ application.
    .DESCRIPTION
        Performs a full PUT update on an application. WARNING: This is a full
        replacement — omitted fields may be reset to defaults. The recommended
        pattern is: Get -> Modify -> Set.
    .PARAMETER Id
        The application/student profile UUID.
    .PARAMETER Data
        A hashtable containing the complete application data.
    .EXAMPLE
        # Get -> Modify -> Set pattern
        $app = Get-EnrolHQApplication -Id $id
        $app | Add-Member -NotePropertyName 'preferred_name' -NotePropertyValue 'Jenny' -Force
        $app.entry_grade = 8
        Set-EnrolHQApplication -Id $id -Data $app
    .EXAMPLE
        # Using a hashtable directly (ensure all required fields are present)
        Set-EnrolHQApplication -Id $id -Data @{
            first_name  = 'Jane'
            last_name   = 'Smith'
            entry_grade = 8
            entry_year  = 2027
        }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Id,

        [Parameter(Mandatory, Position = 1)]
        [object]$Data
    )

    if ($PSCmdlet.ShouldProcess($Id, 'Update EnrolHQ Application')) {
        Write-Verbose 'Set-EnrolHQApplication uses PUT (full replacement). Omitted fields may be reset.'
        Invoke-EnrolHQRestMethod -Method PUT -Endpoint "applications/$Id/" -Body $Data
    }
}
