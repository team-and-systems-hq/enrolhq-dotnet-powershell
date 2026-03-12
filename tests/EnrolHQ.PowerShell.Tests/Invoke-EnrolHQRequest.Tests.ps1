#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-EnrolHQRequest' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    It 'Should make generic GET requests' {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ data = 'user-info' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

        $result = Invoke-EnrolHQRequest -Method GET -Endpoint 'user-data/'
        $result.data | Should -Be 'user-info'
    }

    It 'Should make generic POST requests with body' {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ success = $true }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

        $result = Invoke-EnrolHQRequest -Method POST -Endpoint 'applications/abc/toggle_favorite/'
        $result.success | Should -BeTrue
    }

    It 'Should pass query parameters' {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ count = 5 }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

        Invoke-EnrolHQRequest -Method GET -Endpoint 'applications-list/count/' `
            -QueryParameters @{ entry_year = '2026' }

        Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
            $Uri -like '*entry_year=2026*'
        }
    }
}
