function Get-EnrolHQAllPages {
    <#
    .SYNOPSIS
        Auto-paginates through all pages of an EnrolHQ API endpoint.
    .DESCRIPTION
        Iterates through all pages, returning combined results.
        Writes progress information for large datasets.
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
    $page = 1
    $totalCount = $null

    while ($page -le $MaxPages) {
        $params = @{} + $QueryParameters
        $params['page'] = $page
        $params['page_size'] = $PageSize

        $response = Invoke-EnrolHQRestMethod -Method GET -Endpoint $Endpoint -QueryParameters $params

        if (-not $response) { break }

        # First page: capture total count
        if ($null -eq $totalCount) {
            $totalCount = $response.count
            if ($totalCount -eq 0) {
                Write-Verbose "EnrolHQ: No results found"
                break
            }
            $totalPages = [math]::Ceiling($totalCount / $PageSize)
            Write-Verbose "EnrolHQ: $totalCount total records across $totalPages pages"
        }

        if ($response.results) {
            $allResults.AddRange([object[]]$response.results)
        }

        # Progress reporting
        $percentComplete = [math]::Min(100, [math]::Round(($page / $totalPages) * 100))
        Write-Progress -Activity "Fetching EnrolHQ data" `
            -Status "Page $page of $totalPages ($($allResults.Count) of $totalCount records)" `
            -PercentComplete $percentComplete

        # Check if we've reached the last page
        if (-not $response.next) { break }
        $page++
    }

    Write-Progress -Activity "Fetching EnrolHQ data" -Completed

    return $allResults
}
