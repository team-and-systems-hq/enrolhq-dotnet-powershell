#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Get-EnrolHQMetafields' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    BeforeEach {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{
                field_settings         = [PSCustomObject]@{ parent = [PSCustomObject]@{ first_name = [PSCustomObject]@{ label = 'First name' } } }
                default_field_settings = [PSCustomObject]@{ parent = [PSCustomObject]@{ first_name = [PSCustomObject]@{ label = 'Default first name' } } }
            }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
    }

    It 'Calls the metafields/ endpoint' {
        Get-EnrolHQMetafields | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
            $Uri -like '*metafields/*'
        }
    }

    It 'Rejects an invalid Section' {
        { Get-EnrolHQMetafields -Section 'Bogus' } | Should -Throw
    }

    It 'Returns the full object by default' {
        $result = Get-EnrolHQMetafields
        $result.field_settings | Should -Not -BeNullOrEmpty
        $result.default_field_settings | Should -Not -BeNullOrEmpty
    }

    It 'Returns only field_settings with -Section FieldSettings' {
        $result = Get-EnrolHQMetafields -Section FieldSettings
        $result.parent.first_name.label | Should -Be 'First name'
    }

    It 'Returns only default_field_settings with -Section DefaultFieldSettings' {
        $result = Get-EnrolHQMetafields -Section DefaultFieldSettings
        $result.parent.first_name.label | Should -Be 'Default first name'
    }
}
