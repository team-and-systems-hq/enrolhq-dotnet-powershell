function Get-EnrolHQAnalytics {
    <#
    .SYNOPSIS
        Retrieves analytics and reporting data from EnrolHQ.
    .PARAMETER Report
        The analytics report to retrieve.
    .PARAMETER QueryParameters
        Optional hashtable of query parameters to pass to the report endpoint.
    .EXAMPLE
        Get-EnrolHQAnalytics -Report Statistics
    .EXAMPLE
        Get-EnrolHQAnalytics -Report Conversion -QueryParameters @{ entry_year = 2026 }
    .EXAMPLE
        Get-EnrolHQAnalytics -Report MonthlyChart
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet(
            'Statistics',
            'Conversion',
            'StatusConversion',
            'ApplicationsChart',
            'CurrentSchoolsChart',
            'HowHearChart',
            'MonthlyChart',
            'SuburbsChart'
        )]
        [string]$Report,

        [Parameter()]
        [hashtable]$QueryParameters = @{}
    )

    $endpointMap = @{
        Statistics         = 'application-statistics/'
        Conversion         = 'conversion/'
        StatusConversion   = 'application-status-conversion/'
        ApplicationsChart  = 'charts/applications-chart/'
        CurrentSchoolsChart = 'charts/current-schools-chart/'
        HowHearChart       = 'charts/how-hear-chart/'
        MonthlyChart       = 'charts/monthly-chart/'
        SuburbsChart       = 'charts/suburbs-chart/'
    }

    $endpoint = $endpointMap[$Report]
    Write-Verbose "Fetching analytics: $Report from $endpoint"

    Invoke-EnrolHQRestMethod -Method GET -Endpoint $endpoint -QueryParameters $QueryParameters
}
