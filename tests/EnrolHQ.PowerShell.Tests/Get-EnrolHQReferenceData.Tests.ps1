#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Get-EnrolHQReferenceData' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Parameter validation' {
        It 'Should reject invalid Type' {
            { Get-EnrolHQReferenceData -Type 'InvalidType' } | Should -Throw
        }
    }

    Context 'Endpoint mapping' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count = 2; next = $null
                    results = @(
                        [PSCustomObject]@{ id = '1'; name = 'Item 1' }
                        [PSCustomObject]@{ id = '2'; name = 'Item 2' }
                    )
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
        }

        It 'Should call school-campuses/ for Campuses' {
            Get-EnrolHQReferenceData -Type Campuses
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*school-campuses/*'
            }
        }

        It 'Should call dictionaries/countries/ for Countries' {
            Get-EnrolHQReferenceData -Type Countries
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*dictionaries/countries/*'
            }
        }

        It 'Should call dictionaries/languages/ for Languages' {
            Get-EnrolHQReferenceData -Type Languages
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*dictionaries/languages/*'
            }
        }

        It 'Should call attendance-types/ for AttendanceTypes' {
            Get-EnrolHQReferenceData -Type AttendanceTypes
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*attendance-types/*'
            }
        }

        It 'Should return results as flat list' {
            $results = Get-EnrolHQReferenceData -Type Countries
            $results | Should -HaveCount 2
            $results[0].name | Should -Be 'Item 1'
        }
    }
}
