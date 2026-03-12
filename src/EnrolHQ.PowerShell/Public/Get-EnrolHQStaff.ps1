function Get-EnrolHQStaff {
    <#
    .SYNOPSIS
        Lists EnrolHQ staff members.
    .PARAMETER PageSize
        Number of results per page. Default: 100.
    .PARAMETER Page
        Specific page number.
    .PARAMETER All
        Auto-paginate through all results.
    .EXAMPLE
        Get-EnrolHQStaff -All
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
        Get-EnrolHQAllPages -Endpoint 'staff/' -PageSize $PageSize
    }
    else {
        Get-EnrolHQPage -Endpoint 'staff/' -Page $Page -PageSize $PageSize
    }
}
