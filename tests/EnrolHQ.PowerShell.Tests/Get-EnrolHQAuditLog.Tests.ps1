#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Get-EnrolHQAuditLog' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Parameter validation' {
        It 'Requires either StudentProfileId or ParentId' {
            { Get-EnrolHQAuditLog } | Should -Throw
        }
        It 'Rejects both StudentProfileId and ParentId together' {
            { Get-EnrolHQAuditLog -StudentProfileId 'a' -ParentId 'b' } | Should -Throw
        }
    }

    Context 'Cursor pagination' {
        BeforeEach {
            # Page 1: first request (no cursor) returns a `next` link.
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    next     = 'https://testschool.enrolhq.com.au/api/v2/audit/log/?cursor=PAGE2&page_size=25'
                    previous = $null
                    results  = @([PSCustomObject]@{ updated_at = 't1'; changes = @('change 1') })
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*audit/log/*' -and $Uri -notlike '*cursor=*'
            }

            # Page 2: followed via the cursor link, terminates (next = null).
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    next     = $null
                    previous = 'https://testschool.enrolhq.com.au/api/v2/audit/log/?cursor=PAGE1'
                    results  = @([PSCustomObject]@{ updated_at = 't2'; changes = @('change 2') })
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*cursor=PAGE2*'
            }
        }

        It 'Calls audit/log/ with the student_profile filter and page_size' {
            Get-EnrolHQAuditLog -StudentProfileId 'SP1' -PageSize 25 | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*audit/log/*' -and $Uri -like '*student_profile=SP1*' -and $Uri -like '*page_size=25*'
            }
        }

        It 'Follows the cursor next link to the second page' {
            Get-EnrolHQAuditLog -StudentProfileId 'SP1' | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*cursor=PAGE2*'
            }
        }

        It 'Combines results across all cursor pages' {
            $results = Get-EnrolHQAuditLog -StudentProfileId 'SP1'
            $results | Should -HaveCount 2
            $results[0].changes[0] | Should -Be 'change 1'
            $results[1].changes[0] | Should -Be 'change 2'
        }

        It 'Uses the parent filter in the Parent parameter set' {
            Get-EnrolHQAuditLog -ParentId 'PAR1' | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*audit/log/*' -and $Uri -like '*parent=PAR1*'
            }
        }
    }
}
