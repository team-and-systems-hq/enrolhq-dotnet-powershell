#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-EnrolHQRestMethod (via Invoke-EnrolHQRequest)' {

    BeforeEach {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
            $Uri -like '*accounts/refresh/*'
        }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterEach {
        Disconnect-EnrolHQ
    }

    Context 'When not connected' {
        It 'Should throw if not connected' {
            Disconnect-EnrolHQ
            { Invoke-EnrolHQRequest -Method GET -Endpoint 'test/' } | Should -Throw '*Not connected*'
        }
    }

    Context 'Successful GET requests' {
        It 'Should build correct URL and add auth header' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = '123'; name = 'Test' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $result = Invoke-EnrolHQRequest -Method GET -Endpoint 'staff/123/'
            $result.id | Should -Be '123'

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/staff/123/' -and
                $Method -eq 'GET' -and
                $Headers['Authorization'] -eq 'Token mock-access-token'
            }
        }

        It 'Should append query parameters to URL' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ count = 0; results = @() }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            Invoke-EnrolHQRequest -Method GET -Endpoint 'applications-list/' `
                -QueryParameters @{ entry_year = '2026'; entry_grade = '7' }

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*entry_year=2026*' -and $Uri -like '*entry_grade=7*'
            }
        }
    }

    Context 'POST requests' {
        It 'Should serialize hashtable body as JSON' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'new-123' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $result = Invoke-EnrolHQRequest -Method POST -Endpoint 'notes/' -Body @{
                student_profile = 'abc-123'
                text            = 'Test note'
            }

            $result.id | Should -Be 'new-123'

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Method -eq 'POST' -and
                $ContentType -eq 'application/json; charset=utf-8' -and
                $Body -like '*Test note*'
            }
        }
    }

    Context 'Error handling' {
        It 'Should produce error on 400 Bad Request' {
            Mock Invoke-RestMethod {
                $resp = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::BadRequest)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Bad Request', $resp)
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            { Invoke-EnrolHQRequest -Method POST -Endpoint 'applications/' -Body @{} -ErrorAction Stop } |
                Should -Throw
        }

        It 'Should produce error on 404 Not Found' {
            Mock Invoke-RestMethod {
                $resp = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Not Found', $resp)
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            { Invoke-EnrolHQRequest -Method GET -Endpoint 'applications/bad-id/' -ErrorAction Stop } |
                Should -Throw
        }
    }
}
