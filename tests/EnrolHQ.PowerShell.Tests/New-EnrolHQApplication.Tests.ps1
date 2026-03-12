#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'New-EnrolHQApplication' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Creating with Data hashtable' {
        It 'Should POST to applications endpoint' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    id         = 'new-uuid-123'
                    first_name = 'Jane'
                    last_name  = 'Doe'
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $result = New-EnrolHQApplication -Data @{
                first_name         = 'Jane'
                last_name          = 'Doe'
                dob                = '2015-03-15'
                entry_grade        = 7
                entry_year         = 2027
                application_status = 0
                user_parent        = @{
                    first_name   = 'John'
                    last_name    = 'Doe'
                    email        = 'john@example.com'
                    mobile_phone = '+61400000000'
                }
            } -Confirm:$false

            $result.id | Should -Be 'new-uuid-123'
            $result.first_name | Should -Be 'Jane'

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*applications/*' -and
                $Method -eq 'POST' -and
                $Body -like '*Jane*'
            }
        }
    }

    Context 'Creating with explicit parameters' {
        It 'Should build data from explicit params' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'new-456'; first_name = 'Bob' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $result = New-EnrolHQApplication `
                -FirstName 'Bob' -LastName 'Smith' -Dob '2015-06-01' `
                -EntryGrade 7 -EntryYear 2027 `
                -ParentFirstName 'Mary' -ParentLastName 'Smith' `
                -ParentEmail 'mary@example.com' -Confirm:$false

            $result.id | Should -Be 'new-456'

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Body -like '*Bob*' -and $Body -like '*Mary*'
            }
        }
    }

    Context 'ShouldProcess' {
        It 'Should support -WhatIf' {
            Mock Invoke-RestMethod {} -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            New-EnrolHQApplication -Data @{ first_name = 'Test' } -WhatIf

            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*applications/*' -and $Method -eq 'POST'
            }
        }
    }
}
