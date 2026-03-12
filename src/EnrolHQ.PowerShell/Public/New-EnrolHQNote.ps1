function New-EnrolHQNote {
    <#
    .SYNOPSIS
        Creates a note on a student profile.
    .PARAMETER StudentProfileId
        The student profile UUID.
    .PARAMETER Text
        The note text content.
    .EXAMPLE
        New-EnrolHQNote -StudentProfileId 'abc-123' -Text 'Called parent re: missing documents'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$StudentProfileId,

        [Parameter(Mandatory, Position = 1)]
        [string]$Text
    )

    if ($PSCmdlet.ShouldProcess($StudentProfileId, "Add Note: $($Text.Substring(0, [math]::Min(50, $Text.Length)))...")) {
        Invoke-EnrolHQRestMethod -Method POST -Endpoint 'notes/' -Body @{
            student_profile = $StudentProfileId
            text            = $Text
        }
    }
}
