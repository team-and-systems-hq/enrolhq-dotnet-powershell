#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-EnrolHQBulkOperation' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    BeforeEach {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ status = 'ok' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
    }

    Context 'ChangeStatus' {
        It 'Targets the change_status/ endpoint' {
            Invoke-EnrolHQBulkOperation -Operation ChangeStatus `
                -Data @{ application_status = 2 } `
                -Filter @{ id = @('uuid1', 'uuid2') } -Confirm:$false
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*applications-list/change_status/*'
            }
        }

        It 'Sends ids as repeated id query params, not id__in' {
            Invoke-EnrolHQBulkOperation -Operation ChangeStatus `
                -Data @{ application_status = 2 } `
                -Filter @{ id = @('uuid1', 'uuid2') } -Confirm:$false
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*id=uuid1*' -and $Uri -like '*id=uuid2*' -and $Uri -notlike '*id__in*'
            }
        }

        It 'Supports -WhatIf without calling the API' {
            Invoke-EnrolHQBulkOperation -Operation ChangeStatus `
                -Data @{ application_status = 2 } `
                -Filter @{ id = @('uuid1') } -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -Times 0 -ParameterFilter {
                $Uri -like '*change_status*'
            }
        }
    }
}
