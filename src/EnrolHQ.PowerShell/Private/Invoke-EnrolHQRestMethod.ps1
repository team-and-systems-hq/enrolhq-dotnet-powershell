function Invoke-EnrolHQRestMethod {
    <#
    .SYNOPSIS
        Core HTTP client for EnrolHQ API requests.
    .DESCRIPTION
        Sends authenticated HTTP requests to the EnrolHQ API with automatic
        token refresh on 401, exponential backoff retries for transient errors,
        and structured error handling.
    .NOTES
        This is a private function used by all public cmdlets.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [hashtable]$QueryParameters,

        [Parameter()]
        [int]$TimeoutSec = 0,

        # When set, $Endpoint is treated as a fully-qualified URL and used
        # verbatim (no base URL prefixing, no query-string building). Used to
        # follow the absolute `next` links returned by cursor pagination.
        [Parameter()]
        [switch]$AbsoluteEndpoint
    )

    if (-not $script:EnrolHQConnection) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new('Not connected to EnrolHQ. Run Connect-EnrolHQ first.'),
                'EnrolHQ.NotConnected',
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $null
            )
        )
    }

    $conn = $script:EnrolHQConnection
    $timeout = if ($TimeoutSec -gt 0) { $TimeoutSec } else { $conn.TimeoutSeconds }
    $maxRetries = $conn.MaxRetries

    # Build URL with query parameters. When -AbsoluteEndpoint is set the
    # endpoint is already a full URL (e.g. a cursor `next` link) and is used
    # as-is — the query string it carries must not be touched.
    if ($AbsoluteEndpoint) {
        $url = $Endpoint
    }
    else {
        $url = $conn.BuildUrl($Endpoint)
        if ($QueryParameters -and $QueryParameters.Count -gt 0) {
            $queryParts = [System.Collections.Generic.List[string]]::new()
            foreach ($key in $QueryParameters.Keys) {
                $val = $QueryParameters[$key]
                if ($null -eq $val) { continue }
                $encKey = [System.Uri]::EscapeDataString($key)
                # Emit array values as repeated key=value pairs (e.g. id=a&id=b)
                # rather than a single comma-joined value. This matches Django
                # REST Framework's convention for list/`__in` filters; the
                # bulk change-status endpoint in particular requires repeated
                # `id` params and rejects a comma-joined `id__in`.
                if ($val -is [array]) {
                    foreach ($item in $val) {
                        if ($null -ne $item) {
                            $queryParts.Add("$encKey=$([System.Uri]::EscapeDataString([string]$item))")
                        }
                    }
                }
                else {
                    $queryParts.Add("$encKey=$([System.Uri]::EscapeDataString([string]$val))")
                }
            }
            if ($queryParts.Count -gt 0) {
                $url += '?' + ($queryParts -join '&')
            }
        }
    }

    Write-Verbose "EnrolHQ: $Method $url"

    # Build base request parameters
    $requestParams = @{
        Uri        = $url
        Method     = $Method
        TimeoutSec = $timeout
        Headers    = $conn.GetAuthHeaders()
    }

    if ($Body) {
        if ($Body -is [hashtable] -or $Body -is [System.Collections.IDictionary] -or $Body -is [pscustomobject]) {
            $requestParams['Body'] = ($Body | ConvertTo-Json -Depth 20 -Compress)
            $requestParams['ContentType'] = 'application/json; charset=utf-8'
        }
        else {
            $requestParams['Body'] = $Body
            $requestParams['ContentType'] = 'application/json; charset=utf-8'
        }
        Write-Debug "EnrolHQ: Request body: [redacted, $($requestParams['Body'].Length) chars]"
    }

    # Retry loop with exponential backoff
    $retryableStatusCodes = @(429, 500, 502, 503, 504)
    $lastError = $null

    for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
        if ($attempt -gt 0) {
            $baseDelay = [math]::Pow(2, $attempt - 1)
            $jitter = Get-Random -Minimum 0.0 -Maximum 1.0
            $delay = $baseDelay + $jitter
            Write-Verbose "EnrolHQ: Retry $attempt/$maxRetries after ${delay}s delay"
            Start-Sleep -Seconds $delay
        }

        try {
            $response = Invoke-RestMethod @requestParams -ErrorAction Stop
            Write-Debug "EnrolHQ: Response received successfully"
            return $response
        }
        catch {
            $statusCode = $null
            $responseBody = $null

            if ($_.Exception -is [Microsoft.PowerShell.Commands.HttpResponseException]) {
                $statusCode = [int]$_.Exception.Response.StatusCode
                $responseBody = $_.ErrorDetails.Message
            }
            elseif ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
                try {
                    $stream = $_.Exception.Response.GetResponseStream()
                    $reader = [System.IO.StreamReader]::new($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Dispose()
                }
                catch { }
            }

            Write-Debug "EnrolHQ: HTTP $statusCode"

            # Handle 401: refresh token and retry once
            if ($statusCode -eq 401 -and $attempt -eq 0) {
                Write-Verbose 'EnrolHQ: Access token expired, refreshing...'
                try {
                    $conn.RefreshToken()
                    $requestParams['Headers'] = $conn.GetAuthHeaders()
                    $response = Invoke-RestMethod @requestParams -ErrorAction Stop
                    return $response
                }
                catch {
                    $innerStatus = $null
                    if ($_.Exception -is [Microsoft.PowerShell.Commands.HttpResponseException]) {
                        $innerStatus = [int]$_.Exception.Response.StatusCode
                    }
                    if ($innerStatus -eq 401) {
                        Resolve-EnrolHQError -StatusCode 401 -ResponseBody $responseBody -Endpoint $Endpoint
                        return
                    }
                    # Fall through to retry logic for other errors
                    $lastError = $_
                    continue
                }
            }

            # Check if retryable
            if ($statusCode -in $retryableStatusCodes -and $attempt -lt $maxRetries) {
                # Respect Retry-After header for 429
                if ($statusCode -eq 429) {
                    $retryAfter = $_.Exception.Response?.Headers?['Retry-After']
                    if ($retryAfter -and [int]::TryParse($retryAfter, [ref]$null)) {
                        $delay = [int]$retryAfter
                        Write-Verbose "EnrolHQ: Rate limited, waiting ${delay}s (Retry-After header)"
                        Start-Sleep -Seconds $delay
                    }
                }
                $lastError = $_
                continue
            }

            # Non-retryable or final attempt — resolve to a PowerShell error
            Resolve-EnrolHQError -StatusCode $statusCode -ResponseBody $responseBody -Endpoint $Endpoint
            return
        }
    }

    # Should not reach here, but if we do, throw the last error
    if ($lastError) {
        throw $lastError
    }
}
