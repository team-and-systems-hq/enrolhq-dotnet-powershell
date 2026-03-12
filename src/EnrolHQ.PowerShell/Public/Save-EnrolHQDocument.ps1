function Save-EnrolHQDocument {
    <#
    .SYNOPSIS
        Downloads an EnrolHQ document to a local file.
    .PARAMETER DocumentUrl
        The full URL of the document to download (from the document's 'file' field).
    .PARAMETER DestinationPath
        Local file path to save the downloaded document.
    .EXAMPLE
        $docs = Get-EnrolHQDocuments -StudentProfileId 'abc-123'
        $docs | ForEach-Object { Save-EnrolHQDocument -DocumentUrl $_.file -DestinationPath "./downloads/$($_.filename)" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('file')]
        [string]$DocumentUrl,

        [Parameter(Mandatory, Position = 1)]
        [string]$DestinationPath
    )

    process {
        $conn = $script:EnrolHQConnection
        if (-not $conn) { throw 'Not connected to EnrolHQ. Run Connect-EnrolHQ first.' }

        $destDir = Split-Path $DestinationPath -Parent
        if ($destDir -and -not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        $headers = $conn.GetAuthHeaders()
        Write-Verbose "Downloading document to $DestinationPath"

        Invoke-RestMethod -Uri $DocumentUrl -Method Get -Headers $headers `
            -OutFile $DestinationPath -TimeoutSec $conn.TimeoutSeconds -ErrorAction Stop

        Get-Item $DestinationPath
    }
}
