function Get-EnrolHQEvents {
    <#
    .SYNOPSIS
        Lists EnrolHQ staff events.
    .DESCRIPTION
        Retrieves staff events with optional filtering. Returns a single page
        by default. Use -All to auto-paginate.
    .PARAMETER PageSize
        Number of results per page. Default: 100.
    .PARAMETER Page
        Specific page number.
    .PARAMETER All
        Auto-paginate through all results.
    .EXAMPLE
        Get-EnrolHQEvents

        Get the first page of events.
    .EXAMPLE
        Get-EnrolHQEvents -All

        Get all events (auto-paginated).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Page')]
    param(
        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 100,

        [Parameter(ParameterSetName = 'Page')]
        [int]$Page = 1,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All
    )

    if ($All) {
        Get-EnrolHQAllPages -Endpoint 'staff-events/' -PageSize $PageSize
    }
    else {
        $result = Get-EnrolHQPage -Endpoint 'staff-events/' -Page $Page -PageSize $PageSize
        if ($result) {
            Write-Verbose "Page $($result.Page) of $($result.TotalPages) ($($result.Count) total)"
            $result
        }
    }
}
