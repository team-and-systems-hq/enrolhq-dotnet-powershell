function Send-EnrolHQDocument {
    <#
    .SYNOPSIS
        Uploads a document to an EnrolHQ student profile.
    .DESCRIPTION
        Uploads a local file as a document attached to a student profile.
        Uses the -Form parameter for proper multipart/form-data upload.
    .PARAMETER StudentProfileId
        The student profile UUID.
    .PARAMETER FilePath
        Path to the local file to upload.
    .PARAMETER GroupKind
        The document group kind (e.g. BIRTH_CERTIFICATE, PASSPORT, SCHOOL_REPORT, PHOTO).
    .PARAMETER FileName
        Optional override for the uploaded file name. Defaults to the local file name.
    .EXAMPLE
        Send-EnrolHQDocument -StudentProfileId 'abc-123' -FilePath './report.pdf' -GroupKind 'SCHOOL_REPORT'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$StudentProfileId,

        [Parameter(Mandatory, Position = 1)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath,

        [Parameter(Mandatory, Position = 2)]
        [string]$GroupKind,

        [Parameter()]
        [string]$FileName
    )

    $resolvedPath = Resolve-Path $FilePath
    if (-not $FileName) {
        $FileName = Split-Path $resolvedPath -Leaf
    }

    if ($PSCmdlet.ShouldProcess("$FileName -> $StudentProfileId", 'Upload Document')) {
        $conn = $script:EnrolHQConnection
        if (-not $conn) { throw 'Not connected to EnrolHQ. Run Connect-EnrolHQ first.' }

        $url = $conn.BuildUrl('application-documents/')
        $headers = $conn.GetAuthHeaders()

        $form = @{
            filename        = $FileName
            group_kind      = $GroupKind
            student_profile = $StudentProfileId
            file            = Get-Item -Path $resolvedPath
        }

        try {
            Invoke-RestMethod -Uri $url -Method Post -Headers $headers `
                -Form $form `
                -TimeoutSec $conn.TimeoutSeconds -ErrorAction Stop
        }
        catch {
            $statusCode = $null
            if ($_.Exception -is [Microsoft.PowerShell.Commands.HttpResponseException]) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            Resolve-EnrolHQError -StatusCode $statusCode -ResponseBody $_.ErrorDetails.Message -Endpoint 'application-documents/'
        }
    }
}
