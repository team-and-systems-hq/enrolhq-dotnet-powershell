function Get-EnrolHQAllCursorPages {
    <#
    .SYNOPSIS
        Auto-paginates through a cursor-paginated EnrolHQ API endpoint.
    .DESCRIPTION
        Some endpoints (e.g. audit/log/) use Django REST Framework cursor
        pagination: each page is { next, previous, results } with no total
        `count`. Unlike page-number pagination, the cursor is opaque, so this
        helper follows the absolute `next` URL the server returns verbatim
        rather than incrementing a page number.

        Returns the combined results across all pages.
    .NOTES
        Private function. Use Get-EnrolHQAllPages for page-number endpoints.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter()]
        [hashtable]$QueryParameters = @{},

        [Parameter()]
        [int]$PageSize = 100,

        [Parameter()]
        [int]$MaxPages = 10000
    )

    $allResults = [System.Collections.Generic.List[object]]::new()

    # First request: relative endpoint with filters + page_size.
    $params = @{} + $QueryParameters
    $params['page_size'] = $PageSize
    $response = Invoke-EnrolHQRestMethod -Method GET -Endpoint $Endpoint -QueryParameters $params

    $page = 1
    while ($response -and $page -le $MaxPages) {
        if ($response.results) {
            $allResults.AddRange([object[]]$response.results)
        }

        Write-Progress -Activity "Fetching EnrolHQ data" `
            -Status "Page $page ($($allResults.Count) records)"

        # No `next` cursor means we've reached the last page.
        if (-not $response.next) { break }

        $page++
        # The `next` link is an absolute URL that already encodes the cursor,
        # page_size, and filters — follow it as-is.
        $response = Invoke-EnrolHQRestMethod -Method GET -Endpoint $response.next -AbsoluteEndpoint
    }

    Write-Progress -Activity "Fetching EnrolHQ data" -Completed

    return $allResults
}
