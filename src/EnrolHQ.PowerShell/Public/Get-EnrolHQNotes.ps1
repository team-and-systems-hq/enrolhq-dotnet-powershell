function Get-EnrolHQNotes {
    <#
    .SYNOPSIS
        Lists notes for a student profile.
    .PARAMETER StudentProfileId
        The student profile UUID.
    .EXAMPLE
        Get-EnrolHQNotes -StudentProfileId 'abc-123'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$StudentProfileId
    )

    process {
        Get-EnrolHQAllPages -Endpoint 'notes/' `
            -QueryParameters @{ student_profile = $StudentProfileId } `
            -PageSize 1000
    }
}
