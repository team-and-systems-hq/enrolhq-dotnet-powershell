function Get-EnrolHQReferenceData {
    <#
    .SYNOPSIS
        Retrieves reference/lookup data from EnrolHQ.
    .DESCRIPTION
        Fetches reference data tables used across the platform. All data types
        are auto-paginated and return the complete list.
    .PARAMETER Type
        The type of reference data to retrieve.
    .EXAMPLE
        Get-EnrolHQReferenceData -Type Campuses
    .EXAMPLE
        Get-EnrolHQReferenceData -Type Countries
    .EXAMPLE
        Get-EnrolHQReferenceData -Type Languages | Select-Object id, name
    .EXAMPLE
        Get-EnrolHQReferenceData -Type ApplicationStatusSettings |
            Select-Object application_status, status_label, is_status_enabled

        List per-status labels and flags configured for the school.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet(
            'Campuses',
            'AttendanceTypes',
            'Countries',
            'Languages',
            'Nationalities',
            'SchoolOptions',
            'SocialUnits',
            'Suburbs',
            'Timezones',
            'MedicalConditions',
            'ParentRelationships',
            'ProfileCategories',
            'ProfileCategoryOptions',
            'ApplicationStatusSettings'
        )]
        [string]$Type,

        [Parameter()]
        [hashtable]$QueryParameters = @{}
    )

    $endpointMap = @{
        Campuses              = 'school-campuses/'
        AttendanceTypes       = 'attendance-types/'
        Countries             = 'dictionaries/countries/'
        Languages             = 'dictionaries/languages/'
        Nationalities         = 'dictionaries/nationalities/'
        SchoolOptions         = 'dictionaries/school-options/'
        SocialUnits           = 'dictionaries/social-units/'
        Suburbs               = 'dictionaries/suburbs/'
        Timezones             = 'dictionaries/timezones/'
        MedicalConditions     = 'medical-condition-options/'
        ParentRelationships   = 'parents-relationships/'
        ProfileCategories     = 'profile-categories/'
        ProfileCategoryOptions = 'profile-category-options/'
        ApplicationStatusSettings = 'application-status-settings/'
    }

    $endpoint = $endpointMap[$Type]
    Write-Verbose "Fetching reference data: $Type from $endpoint"

    Get-EnrolHQAllPages -Endpoint $endpoint -QueryParameters $QueryParameters -PageSize 1000
}
