function Get-EnrolHQDocuments {
    <#
    .SYNOPSIS
        Lists documents for a student profile.
    .PARAMETER StudentProfileId
        The student profile UUID.
    .PARAMETER PageSize
        Number of results per page. Default: 1000.
    .EXAMPLE
        Get-EnrolHQDocuments -StudentProfileId 'abc-123'
    .EXAMPLE
        'abc-123' | Get-EnrolHQDocuments
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$StudentProfileId,

        [Parameter()]
        [int]$PageSize = 1000
    )

    process {
        Get-EnrolHQAllPages -Endpoint 'application-documents/' `
            -QueryParameters @{ student_profile = $StudentProfileId } `
            -PageSize $PageSize
    }
}
