function Get-EnrolHQLeadReferences {
    <#
    .SYNOPSIS
        Lists all lead references.
    .DESCRIPTION
        Reads lead-references/ as a flat list. A lead reference identifies
        which form/source a lead came from. Each record has `id`, `name`,
        `slug`, `confirmation_redirect_url` and `is_removable`.

        Use a record's `id` as the `reference` field when creating or
        updating a lead. Also available as
        Get-EnrolHQReferenceData -Type LeadReferences.
    .PARAMETER PageSize
        Records fetched per request. Default: 1000.
    .EXAMPLE
        Get-EnrolHQLeadReferences | Select-Object name, slug, id
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 1000
    )

    Write-Verbose 'Fetching lead references from lead-references/'
    Get-EnrolHQAllPages -Endpoint 'lead-references/' -PageSize $PageSize
}
