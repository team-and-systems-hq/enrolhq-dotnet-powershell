function Resolve-EnrolHQError {
    <#
    .SYNOPSIS
        Converts HTTP errors into structured PowerShell errors.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$StatusCode,

        [Parameter()]
        [string]$ResponseBody,

        [Parameter()]
        [string]$Endpoint
    )

    $detail = $null
    if ($ResponseBody) {
        try {
            $parsed = $ResponseBody | ConvertFrom-Json -ErrorAction Stop
            $detail = if ($parsed.detail) { $parsed.detail } else { $parsed }
        }
        catch {
            $detail = $ResponseBody
        }
    }

    $detailString = if ($detail -is [string]) { $detail } else { $detail | ConvertTo-Json -Depth 5 -Compress }

    switch ($StatusCode) {
        400 {
            $message = "Validation error on $Endpoint"
            if ($detailString) { $message += ": $detailString" }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new($message),
                'EnrolHQ.ValidationError',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $Endpoint
            )
        }
        401 {
            $message = "Authentication failed for $Endpoint. Check your API token."
            if ($detailString) { $message += " Detail: $detailString" }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Security.Authentication.AuthenticationException]::new($message),
                'EnrolHQ.AuthenticationError',
                [System.Management.Automation.ErrorCategory]::AuthenticationError,
                $Endpoint
            )
        }
        403 {
            $message = "Access forbidden: $Endpoint"
            if ($detailString) { $message += ". $detailString" }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.UnauthorizedAccessException]::new($message),
                'EnrolHQ.ForbiddenError',
                [System.Management.Automation.ErrorCategory]::PermissionDenied,
                $Endpoint
            )
        }
        404 {
            $message = "Not found: $Endpoint"
            if ($detailString) { $message += ". $detailString" }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new($message),
                'EnrolHQ.NotFoundError',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Endpoint
            )
        }
        429 {
            $message = "Rate limit exceeded on $Endpoint. Please wait before retrying."
            if ($detailString) { $message += " $detailString" }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new($message),
                'EnrolHQ.RateLimitError',
                [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
                $Endpoint
            )
        }
        default {
            $message = "API error (HTTP $StatusCode) on $Endpoint"
            if ($detailString) { $message += ": $detailString" }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Net.Http.HttpRequestException]::new($message),
                'EnrolHQ.ApiError',
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $Endpoint
            )
        }
    }

    Write-Error -ErrorRecord $errorRecord
}
