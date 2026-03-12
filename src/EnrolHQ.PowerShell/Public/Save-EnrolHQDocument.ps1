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
        if (-not $conn) {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.InvalidOperationException]::new('Not connected to EnrolHQ. Run Connect-EnrolHQ first.'),
                    'EnrolHQ.NotConnected',
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $null
                )
            )
        }

        $destDir = Split-Path $DestinationPath -Parent
        if ($destDir -and -not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        $headers = $conn.GetAuthHeaders()
        Write-Verbose "Downloading document to $DestinationPath"

        try {
            Invoke-RestMethod -Uri $DocumentUrl -Method Get -Headers $headers `
                -OutFile $DestinationPath -TimeoutSec $conn.TimeoutSeconds -ErrorAction Stop
        }
        catch {
            $statusCode = $null
            if ($_.Exception -is [Microsoft.PowerShell.Commands.HttpResponseException]) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            Resolve-EnrolHQError -StatusCode $statusCode -ResponseBody $_.ErrorDetails.Message -Endpoint $DocumentUrl
            return
        }

        Get-Item $DestinationPath
    }
}
