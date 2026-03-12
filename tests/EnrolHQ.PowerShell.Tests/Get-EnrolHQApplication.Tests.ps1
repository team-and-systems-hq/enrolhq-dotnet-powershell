#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Get-EnrolHQApplication' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Fetching by ID' {
        It 'Should return full application detail' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    id                 = 'abc-123'
                    first_name         = 'Alice'
                    last_name          = 'Smith'
                    application_status = 4
                    entry_year         = 2026
                    entry_grade        = 7
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $result = Get-EnrolHQApplication -Id 'abc-123'

            $result.id | Should -Be 'abc-123'
            $result.first_name | Should -Be 'Alice'

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*applications/abc-123/*'
            }
        }

        It 'Should accept pipeline input' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'pipe-123'; first_name = 'Bob' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $result = 'pipe-123' | Get-EnrolHQApplication
            $result.id | Should -Be 'pipe-123'
        }
    }
}
