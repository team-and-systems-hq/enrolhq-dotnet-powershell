function Invoke-EnrolHQRequest {
    <#
    .SYNOPSIS
        Makes a generic authenticated request to the EnrolHQ API.
    .DESCRIPTION
        Escape hatch for any API endpoint not covered by dedicated cmdlets.
        Handles authentication, retries, and error mapping automatically.
    .PARAMETER Method
        HTTP method (GET, POST, PUT, DELETE).
    .PARAMETER Endpoint
        API endpoint path (e.g. 'applications-list/' or 'staff/123/').
    .PARAMETER Body
        Request body as a hashtable (will be serialized to JSON).
    .PARAMETER QueryParameters
        Query string parameters as a hashtable.
    .EXAMPLE
        Invoke-EnrolHQRequest -Method GET -Endpoint 'user-data/'
    .EXAMPLE
        Invoke-EnrolHQRequest -Method POST -Endpoint 'applications/abc-123/toggle_favorite/'
    .EXAMPLE
        Invoke-EnrolHQRequest -Method GET -Endpoint 'applications-list/' -QueryParameters @{
            entry_year = 2026
            page_size = 10
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method,

        [Parameter(Mandatory, Position = 1)]
        [string]$Endpoint,

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [hashtable]$QueryParameters
    )

    $params = @{
        Method   = $Method
        Endpoint = $Endpoint
    }

    if ($Body) { $params['Body'] = $Body }
    if ($QueryParameters) { $params['QueryParameters'] = $QueryParameters }

    Invoke-EnrolHQRestMethod @params
}
