function Connect-EnrolHQ {
    <#
    .SYNOPSIS
        Establishes a connection to the EnrolHQ API.
    .DESCRIPTION
        Authenticates to the EnrolHQ API using an API token and stores the connection
        in module scope. Supports environment variables, explicit parameters, and the
        SecretManagement module.

        The API token is a long-lived token obtained from your EnrolHQ profile
        (Profile icon > API Token). This cmdlet exchanges it for a short-lived
        access token via the /accounts/refresh/ endpoint.
    .PARAMETER Instance
        Your EnrolHQ domain (e.g., "enrol.cranbrook.nsw.edu.au" or
        "demo.enrolhq.com.au").
    .PARAMETER ApiToken
        The long-lived API token. Can be a string or SecureString.
        If not provided, checks ENROLHQ_API_TOKEN environment variable,
        then tries the SecretManagement module (Get-Secret -Name 'EnrolHQ-ApiToken').
    .PARAMETER BaseUrl
        Full API base URL override. Use this instead of Instance if you have
        a custom domain or non-standard URL.
    .PARAMETER TimeoutSeconds
        HTTP request timeout in seconds. Default: 30.
    .PARAMETER MaxRetries
        Maximum number of retries for transient errors (429, 5xx). Default: 3.
    .PARAMETER PassThru
        Return the connection object.
    .EXAMPLE
        Connect-EnrolHQ -Instance 'enrol.cranbrook.nsw.edu.au' -ApiToken $token

        Connect using your EnrolHQ domain.
    .EXAMPLE
        $env:ENROLHQ_INSTANCE = 'enrol.cranbrook.nsw.edu.au'
        $env:ENROLHQ_API_TOKEN = 'your_token_here'
        Connect-EnrolHQ

        Connect using environment variables.
    .EXAMPLE
        Connect-EnrolHQ -BaseUrl 'https://custom.domain.com/api/v2/' -ApiToken $token

        Connect using a full base URL override.
    .EXAMPLE
        # Azure Automation: retrieve token from Automation variable
        $token = Get-AutomationVariable -Name 'EnrolHQ-ApiToken'
        Connect-EnrolHQ -Instance 'myschool' -ApiToken $token
    .NOTES
        The connection is stored in module scope and used by all subsequent cmdlets.
        Call Disconnect-EnrolHQ to clear the connection.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Instance')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Instance')]
        [string]$Instance,

        [Parameter(Position = 1)]
        [object]$ApiToken,

        [Parameter(Mandatory, ParameterSetName = 'BaseUrl')]
        [string]$BaseUrl,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$TimeoutSeconds = 30,

        [Parameter()]
        [ValidateRange(0, 10)]
        [int]$MaxRetries = 3,

        [Parameter()]
        [switch]$PassThru
    )

    # Resolve API token
    $resolvedToken = $null

    if ($ApiToken) {
        if ($ApiToken -is [System.Security.SecureString]) {
            $resolvedToken = [System.Net.NetworkCredential]::new('', $ApiToken).Password
        }
        elseif ($ApiToken -is [string]) {
            $resolvedToken = $ApiToken
        }
        else {
            throw 'ApiToken must be a string or SecureString'
        }
    }

    if (-not $resolvedToken) {
        $resolvedToken = $env:ENROLHQ_API_TOKEN
    }

    if (-not $resolvedToken) {
        # Try SecretManagement module
        if (Get-Command -Name 'Get-Secret' -ErrorAction SilentlyContinue) {
            try {
                Write-Verbose 'Attempting to retrieve API token from SecretManagement module...'
                $secret = Get-Secret -Name 'EnrolHQ-ApiToken' -AsPlainText -ErrorAction Stop
                $resolvedToken = $secret
            }
            catch {
                Write-Verbose "SecretManagement lookup failed: $_"
            }
        }
    }

    if (-not $resolvedToken) {
        throw @(
            'API token is required. Provide it via:'
            '  -ApiToken parameter'
            '  ENROLHQ_API_TOKEN environment variable'
            '  SecretManagement module (secret name: EnrolHQ-ApiToken)'
        ) -join "`n"
    }

    # Resolve base URL
    $resolvedBaseUrl = $null

    if ($BaseUrl) {
        $resolvedBaseUrl = $BaseUrl
    }
    elseif ($Instance) {
        $resolvedBaseUrl = "https://$Instance/api/v2/"
    }
    else {
        $resolvedBaseUrl = $env:ENROLHQ_BASE_URL
        if (-not $resolvedBaseUrl) {
            $envInstance = $env:ENROLHQ_INSTANCE
            if ($envInstance) {
                $resolvedBaseUrl = "https://$envInstance/api/v2/"
            }
        }
    }

    if (-not $resolvedBaseUrl) {
        throw @(
            'Instance or base URL is required. Provide it via:'
            '  -Instance parameter'
            '  -BaseUrl parameter'
            '  ENROLHQ_INSTANCE or ENROLHQ_BASE_URL environment variable'
        ) -join "`n"
    }

    # Create connection and authenticate
    Write-Verbose "Connecting to EnrolHQ at $resolvedBaseUrl"
    $connection = [EnrolHQConnection]::new($resolvedBaseUrl, $resolvedToken)
    $connection.TimeoutSeconds = $TimeoutSeconds
    $connection.MaxRetries = $MaxRetries

    try {
        $connection.RefreshToken()
        Write-Verbose 'Successfully authenticated to EnrolHQ'
    }
    catch {
        throw "Failed to connect to EnrolHQ: $_"
    }

    $script:EnrolHQConnection = $connection

    if ($PassThru) {
        [PSCustomObject]@{
            PSTypeName = 'EnrolHQ.Connection'
            BaseUrl    = $connection.BaseUrl
            Connected  = $connection.IsConnected
        }
    }
}
