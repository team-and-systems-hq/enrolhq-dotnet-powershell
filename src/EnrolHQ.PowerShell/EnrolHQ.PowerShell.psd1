@{
    RootModule        = 'EnrolHQ.PowerShell.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = 'a3f7c8e1-5d42-4b9a-9e6f-1a2b3c4d5e6f'
    Author            = 'Team and Systems HQ'
    CompanyName       = 'Team and Systems HQ'
    Copyright         = '(c) 2026 Team and Systems HQ. All rights reserved.'
    Description       = 'PowerShell module for the EnrolHQ school enrolments and admissions API'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Connect-EnrolHQ'
        'Disconnect-EnrolHQ'
        'Get-EnrolHQApplication'
        'Get-EnrolHQApplications'
        'Get-EnrolHQApplicationCount'
        'New-EnrolHQApplication'
        'Set-EnrolHQApplication'
        'Get-EnrolHQEvent'
        'Get-EnrolHQEvents'
        'New-EnrolHQEvent'
        'Set-EnrolHQEvent'
        'Remove-EnrolHQEvent'
        'Get-EnrolHQStaff'
        'Get-EnrolHQStaffMember'
        'Get-EnrolHQDocuments'
        'Send-EnrolHQDocument'
        'Save-EnrolHQDocument'
        'Remove-EnrolHQDocument'
        'Get-EnrolHQNotes'
        'New-EnrolHQNote'
        'Get-EnrolHQActivityLog'
        'Get-EnrolHQAuditLog'
        'Get-EnrolHQCmsSettings'
        'Get-EnrolHQMetafields'
        'Get-EnrolHQReferenceData'
        'Get-EnrolHQAnalytics'
        'Invoke-EnrolHQRequest'
        'Invoke-EnrolHQBulkOperation'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('EnrolHQ', 'School', 'Enrolment', 'Admissions', 'API', 'REST')
            LicenseUri   = 'https://github.com/team-and-systems-hq/enrolhq-dotnet-powershell/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/team-and-systems-hq/enrolhq-dotnet-powershell'
            ReleaseNotes = 'v1.1.0: Add read-only audit log (cursor pagination), CMS settings, metafields, activity log, and application-status-settings reference data. Fix bulk ChangeStatus to use repeated id query params.'
        }
    }
}
