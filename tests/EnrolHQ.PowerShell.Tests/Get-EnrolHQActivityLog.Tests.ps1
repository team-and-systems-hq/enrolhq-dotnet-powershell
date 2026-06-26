#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Get-EnrolHQActivityLog' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Parameter validation' {
        It 'Requires StudentProfileId' {
            { Get-EnrolHQActivityLog } | Should -Throw
        }
    }

    Context 'Request' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count = 1; next = $null
                    results = @([PSCustomObject]@{ activity_kind = 'EMAIL'; description = 'Sent welcome email' })
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
        }

        It 'Calls activity-log/ with the student_profile filter' {
            Get-EnrolHQActivityLog -StudentProfileId 'SP1' | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*activity-log/*' -and $Uri -like '*student_profile=SP1*'
            }
        }

        It 'Returns the entries' {
            $entries = Get-EnrolHQActivityLog -StudentProfileId 'SP1'
            $entries | Should -HaveCount 1
            $entries[0].activity_kind | Should -Be 'EMAIL'
        }
    }
}
