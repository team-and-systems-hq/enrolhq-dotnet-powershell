function Get-EnrolHQPage {
    <#
    .SYNOPSIS
        Fetches a single page from a paginated EnrolHQ API endpoint.
    .DESCRIPTION
        Returns a PSCustomObject with Count, Next, Previous, Results properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter()]
        [hashtable]$QueryParameters = @{},

        [Parameter()]
        [int]$Page = 1,

        [Parameter()]
        [int]$PageSize = 100
    )

    $params = @{} + $QueryParameters
    $params['page'] = $Page
    $params['page_size'] = $PageSize

    $response = Invoke-EnrolHQRestMethod -Method GET -Endpoint $Endpoint -QueryParameters $params

    if (-not $response) { return $null }

    [PSCustomObject]@{
        PSTypeName = 'EnrolHQ.PaginatedResult'
        Count      = $response.count
        Next       = $response.next
        Previous   = $response.previous
        Results    = $response.results
        Page       = $Page
        PageSize   = $PageSize
        TotalPages = [math]::Ceiling($response.count / $PageSize)
    }
}
