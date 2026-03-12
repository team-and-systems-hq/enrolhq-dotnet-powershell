#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'PATCH method support' {

    BeforeEach {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
            $Uri -like '*accounts/refresh/*'
        }
        Connect-EnrolHQ -Instance 'testschool' -ApiToken 'test-token'
    }

    AfterEach {
        Disconnect-EnrolHQ
    }

    Context 'Invoke-EnrolHQRequest with PATCH' {
        It 'Should accept PATCH as a valid method' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    id                = 'app-001'
                    first_name        = 'Updated'
                    last_name         = 'Name'
                    application_status = 4
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -notlike '*accounts/refresh/*'
            }

            $result = Invoke-EnrolHQRequest -Method PATCH -Endpoint 'applications/app-001/' -Body @{
                first_name = 'Updated'
            }

            $result.first_name | Should -Be 'Updated'

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Method -eq 'PATCH' -and
                $Body -like '*Updated*'
            }
        }

        It 'Should send PATCH with JSON content type' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'app-002' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -notlike '*accounts/refresh/*'
            }

            Invoke-EnrolHQRequest -Method PATCH -Endpoint 'applications/app-002/' -Body @{
                application_status = 5
            }

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $ContentType -eq 'application/json; charset=utf-8' -and
                $Method -eq 'PATCH'
            }
        }

        It 'Should build correct URL for PATCH requests' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'app-003' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -notlike '*accounts/refresh/*'
            }

            Invoke-EnrolHQRequest -Method PATCH -Endpoint 'applications/app-003/'

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/applications/app-003/' -and
                $Method -eq 'PATCH'
            }
        }
    }

    Context 'Invoke-EnrolHQRestMethod with PATCH' {
        It 'Should validate PATCH in ValidateSet' {
            # PATCH should not throw a parameter validation error
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'test' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -notlike '*accounts/refresh/*'
            }

            { Invoke-EnrolHQRequest -Method PATCH -Endpoint 'test/' } | Should -Not -Throw
        }

        It 'Should still reject invalid methods' {
            { Invoke-EnrolHQRequest -Method INVALID -Endpoint 'test/' } | Should -Throw
        }
    }
}
