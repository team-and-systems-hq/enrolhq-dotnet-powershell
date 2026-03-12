#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Pagination' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Auto-pagination collects all pages' {
        It 'Should iterate through 3 pages and return all results' {
            Mock Invoke-RestMethod {
                if ($Uri -like '*page=3*') {
                    [PSCustomObject]@{
                        count = 5; next = $null; previous = 'prev'
                        results = @([PSCustomObject]@{ id = '5' })
                    }
                }
                elseif ($Uri -like '*page=2*') {
                    [PSCustomObject]@{
                        count = 5; next = 'http://next3'; previous = 'prev'
                        results = @(
                            [PSCustomObject]@{ id = '3' }
                            [PSCustomObject]@{ id = '4' }
                        )
                    }
                }
                else {
                    [PSCustomObject]@{
                        count = 5; next = 'http://next2'; previous = $null
                        results = @(
                            [PSCustomObject]@{ id = '1' }
                            [PSCustomObject]@{ id = '2' }
                        )
                    }
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $results = Get-EnrolHQApplications -All -PageSize 2
            $results | Should -HaveCount 5
        }
    }

    Context 'Empty results' {
        It 'Should handle zero results' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ count = 0; next = $null; previous = $null; results = @() }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $results = Get-EnrolHQApplications -All
            $results | Should -HaveCount 0
        }
    }

    Context 'Single page result' {
        It 'Should return PaginatedResult with metadata' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count = 2; next = $null; previous = $null
                    results = @(
                        [PSCustomObject]@{ id = '1' }
                        [PSCustomObject]@{ id = '2' }
                    )
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $result = Get-EnrolHQApplications -Page 1 -PageSize 10
            $result.Count | Should -Be 2
            $result.Page | Should -Be 1
            $result.TotalPages | Should -Be 1
            $result.Results | Should -HaveCount 2
        }
    }
}
