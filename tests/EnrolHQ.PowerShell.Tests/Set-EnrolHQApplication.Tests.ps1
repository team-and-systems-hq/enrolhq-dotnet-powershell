#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Set-EnrolHQApplication' {

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

    Context 'PUT update' {
        It 'Should send PUT request to correct endpoint' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    id                = 'app-001'
                    first_name        = 'Alice'
                    last_name         = 'Smith'
                    application_status = 4
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -notlike '*accounts/refresh/*'
            }

            $result = Set-EnrolHQApplication -Id 'app-001' -Data @{
                first_name         = 'Alice'
                last_name          = 'Smith'
                application_status = 4
            }

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/applications/app-001/' -and
                $Method -eq 'PUT'
            }
        }

        It 'Should serialize data as JSON' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'app-002' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -notlike '*accounts/refresh/*'
            }

            Set-EnrolHQApplication -Id 'app-002' -Data @{
                preferred_name = 'Jenny'
                entry_grade    = 8
            }

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $ContentType -eq 'application/json; charset=utf-8' -and
                $Body -like '*Jenny*' -and
                $Body -like '*entry_grade*'
            }
        }
    }

    Context 'ShouldProcess' {
        It 'Should support -WhatIf' {
            Mock Invoke-RestMethod {} -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -notlike '*accounts/refresh/*'
            }

            Set-EnrolHQApplication -Id 'app-003' -Data @{ first_name = 'Test' } -WhatIf

            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -notlike '*accounts/refresh/*'
            }
        }
    }

    Context 'Verbose output' {
        It 'Should emit verbose message about PUT replacement semantics' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'app-004' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -notlike '*accounts/refresh/*'
            }

            $verboseOutput = Set-EnrolHQApplication -Id 'app-004' -Data @{
                first_name = 'Test'
            } -Verbose 4>&1

            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages | Should -Not -BeNullOrEmpty
            ($verboseMessages | ForEach-Object { $_.Message }) -join ' ' | Should -Match 'PUT'
        }
    }
}
