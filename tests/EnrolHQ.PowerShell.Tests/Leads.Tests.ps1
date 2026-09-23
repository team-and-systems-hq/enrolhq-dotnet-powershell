#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Leads cmdlets' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Get-EnrolHQLeads' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count = 10; next = $null; previous = $null
                    results = @([PSCustomObject]@{ id = 'l1'; email = 'parent@example.com' })
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
        }

        It 'Calls leads/ with page and page_size' {
            $page = Get-EnrolHQLeads -Page 2 -PageSize 25
            $page.Count | Should -Be 10
            $page.Results[0].id | Should -Be 'l1'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*leads/?*' -and $Uri -like '*page=2*' -and $Uri -like '*page_size=25*'
            }
        }

        It 'Forwards is_email_unique and has_student_profile as lower-case booleans' {
            Get-EnrolHQLeads -IsEmailUnique $false -HasStudentProfile $true | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*is_email_unique=false*' -and $Uri -like '*has_student_profile=true*'
            }
        }

        It 'Returns a flat list with -All' {
            $leads = Get-EnrolHQLeads -All
            $leads | Should -HaveCount 1
            $leads[0].email | Should -Be 'parent@example.com'
        }
    }

    Context 'Get-EnrolHQLead' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'l1'; email = 'parent@example.com'; lead_status = 'NEW' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
        }

        It 'Calls leads/{id}/' {
            $lead = Get-EnrolHQLead -Id 'l1'
            $lead.email | Should -Be 'parent@example.com'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/leads/l1/' -and $Method -eq 'GET'
            }
        }

        It 'Accepts pipeline input by property name' {
            [PSCustomObject]@{ id = 'l1' } | Get-EnrolHQLead | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*leads/l1/*'
            }
        }
    }

    Context 'New-EnrolHQLead' {
        It 'POSTs the payload to leads/' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'new-lead'; email = 'parent@example.com' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $result = New-EnrolHQLead -Data @{
                email           = 'parent@example.com'
                first_name      = 'Jane'
                student_profile = 'profile-uuid'
            } -Confirm:$false

            $result.id | Should -Be 'new-lead'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/leads/' -and
                $Method -eq 'POST' -and
                $Body -like '*parent@example.com*' -and
                $Body -like '*profile-uuid*'
            }
        }

        It 'Supports -WhatIf' {
            Mock Invoke-RestMethod {} -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            New-EnrolHQLead -Data @{ email = 'x@example.com' } -WhatIf

            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Method -eq 'POST' -and $Uri -like '*leads/*'
            }
        }
    }

    Context 'Set-EnrolHQLead' {
        It 'PUTs the full object to leads/{id}/' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'l1'; first_name = 'Edited' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $result = Set-EnrolHQLead -Id 'l1' -Data @{ id = 'l1'; first_name = 'Edited' } -Confirm:$false

            $result.first_name | Should -Be 'Edited'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/leads/l1/' -and
                $Method -eq 'PUT' -and
                $Body -like '*Edited*'
            }
        }

        It 'Supports -WhatIf' {
            Mock Invoke-RestMethod {} -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            Set-EnrolHQLead -Id 'l1' -Data @{ first_name = 'x' } -WhatIf

            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Method -eq 'PUT'
            }
        }
    }
}
