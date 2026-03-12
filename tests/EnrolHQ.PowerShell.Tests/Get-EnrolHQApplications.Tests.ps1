#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Get-EnrolHQApplications' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Single page (default)' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count    = 2
                    next     = $null
                    previous = $null
                    results  = @(
                        [PSCustomObject]@{ id = '1'; first_name = 'Alice'; last_name = 'Smith'; application_status = 0 }
                        [PSCustomObject]@{ id = '2'; first_name = 'Bob'; last_name = 'Jones'; application_status = 2 }
                    )
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
        }

        It 'Should return paginated result object' {
            $result = Get-EnrolHQApplications
            $result.Count | Should -Be 2
            $result.Results | Should -HaveCount 2
            $result.Results[0].first_name | Should -Be 'Alice'
        }

        It 'Should pass EntryYear filter' {
            Get-EnrolHQApplications -EntryYear 2026
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*entry_year=2026*'
            }
        }

        It 'Should pass Search filter' {
            Get-EnrolHQApplications -Search 'Smith'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*search=Smith*'
            }
        }

        It 'Should pass multiple ApplicationStatus values' {
            Get-EnrolHQApplications -ApplicationStatus @(0, 1, 2)
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*application_statuses=0*1*2*'
            }
        }

        It 'Should respect PageSize parameter' {
            Get-EnrolHQApplications -PageSize 50
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*page_size=50*'
            }
        }
    }

    Context 'Auto-pagination with -All' {
        It 'Should return all results across pages' {
            Mock Invoke-RestMethod {
                if ($Uri -like '*page=2*') {
                    [PSCustomObject]@{
                        count = 3; next = $null; previous = 'prev'
                        results = @([PSCustomObject]@{ id = '3'; first_name = 'Charlie' })
                    }
                }
                else {
                    [PSCustomObject]@{
                        count = 3; next = 'http://next'; previous = $null
                        results = @(
                            [PSCustomObject]@{ id = '1'; first_name = 'Alice' }
                            [PSCustomObject]@{ id = '2'; first_name = 'Bob' }
                        )
                    }
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $results = Get-EnrolHQApplications -All -PageSize 2
            $results | Should -HaveCount 3
        }
    }
}
