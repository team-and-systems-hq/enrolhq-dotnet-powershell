#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Lead references' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Get-EnrolHQLeadReferences' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count = 1; next = $null
                    results = @([PSCustomObject]@{ id = 'ref-1'; name = 'Keep Updated'; slug = 'keep-updated' })
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
        }

        It 'Calls lead-references/ with page_size 1000 and returns a flat list' {
            $refs = Get-EnrolHQLeadReferences
            $refs | Should -HaveCount 1
            $refs[0].slug | Should -Be 'keep-updated'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*lead-references/?*' -and $Uri -like '*page_size=1000*'
            }
        }

        It 'Is also reachable via Get-EnrolHQReferenceData -Type LeadReferences' {
            Get-EnrolHQReferenceData -Type LeadReferences | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*lead-references/*'
            }
        }
    }

    Context 'New-EnrolHQLeadReference' {
        BeforeEach {
            # GET school/ — a fresh object every call (the cmdlet mutates it).
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    name            = 'Test School'
                    lead_references = @(
                        [PSCustomObject]@{ id = 'ref-1'; name = 'Keep Updated'; slug = 'keep-updated' }
                    )
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*school/*' -and $Method -eq 'GET' }

            # PUT school/
            Mock Invoke-RestMethod {
                [PSCustomObject]@{}
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*school/*' -and $Method -eq 'PUT' }

            # GET lead-references/ after the save — includes the new record.
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count = 2; next = $null
                    results = @(
                        [PSCustomObject]@{ id = 'ref-1'; name = 'Keep Updated'; slug = 'keep-updated' }
                        [PSCustomObject]@{ id = 'ref-2'; name = 'Open Day'; slug = 'open-day' }
                    )
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*lead-references/*' }
        }

        It 'Round-trips school/: GET, PUT with the new reference appended, then re-reads lead-references/' {
            $created = New-EnrolHQLeadReference -Name 'Open Day' -Slug 'open-day' -Confirm:$false

            $created.id | Should -Be 'ref-2'
            $created.slug | Should -Be 'open-day'

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/school/' -and $Method -eq 'GET'
            }
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/school/' -and $Method -eq 'PUT' -and
                $Body -like '*"slug":"open-day"*' -and
                $Body -like '*"confirmation_redirect_url":""*' -and
                $Body -like '*"is_removable":true*' -and
                $Body -like '*"id":"ref-1"*'      # existing references preserved
            }
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*lead-references/*'
            }
        }

        It 'Derives the slug from the name' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count = 1; next = $null
                    results = @([PSCustomObject]@{ id = 'ref-2'; name = 'Open Day 2027!'; slug = 'open-day-2027' })
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*lead-references/*' }

            $created = New-EnrolHQLeadReference -Name 'Open Day 2027!' -Confirm:$false

            $created.slug | Should -Be 'open-day-2027'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Method -eq 'PUT' -and $Body -like '*"slug":"open-day-2027"*'
            }
        }

        It 'Surfaces a failed school/ read as itself and writes nothing' {
            Mock Invoke-RestMethod {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new(
                    'Forbidden', [System.Net.Http.HttpResponseMessage]::new(403))
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*school/*' -and $Method -eq 'GET' }

            { New-EnrolHQLeadReference -Name 'Open Day' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*forbidden*'

            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Method -eq 'PUT'
            }
        }

        It 'Rejects a duplicate slug without writing anything' {
            { New-EnrolHQLeadReference -Name 'Keep Updated' -Slug 'keep-updated' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*keep-updated*'

            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Method -eq 'PUT'
            }
        }

        It 'Throws when the reference is missing after saving' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ count = 0; next = $null; results = @() }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*lead-references/*' }

            { New-EnrolHQLeadReference -Name 'Open Day' -Slug 'open-day' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*open-day*'
        }

        It 'Supports -WhatIf (reads school/, never PUTs)' {
            New-EnrolHQLeadReference -Name 'Open Day' -WhatIf

            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Method -eq 'PUT'
            }
        }
    }
}
