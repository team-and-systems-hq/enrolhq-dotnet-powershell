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
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
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

    Context 'Nested detail-only data via -Section' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    id                 = 'abc-123'
                    emergency_contacts = @([PSCustomObject]@{ first_name = 'Ada'; relationship_to_student = 'Aunt' })
                    medical_data       = [PSCustomObject]@{ medicare_number = '123' }
                    guardians          = @()
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*applications/abc-123/*' }
        }

        It 'Returns the emergency contacts list from the detail endpoint' {
            $contacts = @(Get-EnrolHQApplication -Id 'abc-123' -Section EmergencyContacts)
            $contacts | Should -HaveCount 1
            $contacts[0].first_name | Should -Be 'Ada'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*applications/abc-123/*'
            }
        }

        It 'Returns the medical data object' {
            (Get-EnrolHQApplication -Id 'abc-123' -Section MedicalData).medicare_number | Should -Be '123'
        }

        It 'Returns an empty list for guardians when none exist' {
            @(Get-EnrolHQApplication -Id 'abc-123' -Section Guardians) | Should -HaveCount 0
        }

        It 'Defaults to empty values when the fields are absent' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'bare' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*applications/bare/*' }

            @(Get-EnrolHQApplication -Id 'bare' -Section EmergencyContacts) | Should -HaveCount 0
            @(Get-EnrolHQApplication -Id 'bare' -Section Guardians) | Should -HaveCount 0
            $medical = Get-EnrolHQApplication -Id 'bare' -Section MedicalData
            # Pester treats an empty PSCustomObject as "null or empty", so
            # assert on the type and property count instead.
            ($null -eq $medical) | Should -BeFalse
            $medical | Should -BeOfType [System.Management.Automation.PSCustomObject]
            @($medical.PSObject.Properties) | Should -HaveCount 0
        }

        It 'Rejects an unknown section' {
            { Get-EnrolHQApplication -Id 'abc-123' -Section Nope } | Should -Throw
        }
    }
}
