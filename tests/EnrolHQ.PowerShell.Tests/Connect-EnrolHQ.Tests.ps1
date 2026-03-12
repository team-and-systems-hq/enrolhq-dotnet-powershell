#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Connect-EnrolHQ' {

    BeforeEach {
        Disconnect-EnrolHQ -ErrorAction SilentlyContinue
        $env:ENROLHQ_INSTANCE = $null
        $env:ENROLHQ_API_TOKEN = $null
        $env:ENROLHQ_BASE_URL = $null
    }

    Context 'Parameter validation' {

        It 'Should fail when no parameters and no env vars' {
            { Connect-EnrolHQ } | Should -Throw '*API token is required*'
        }

        It 'Should fail when ApiToken is provided without Instance or BaseUrl' {
            { Connect-EnrolHQ -ApiToken 'test-token' } | Should -Throw '*Instance or base URL is required*'
        }
    }

    Context 'Connecting with explicit parameters' {

        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ access_token = 'mock-access-token-123' }
            } -ModuleName EnrolHQ.PowerShell
        }

        It 'Should connect with Instance and ApiToken' {
            Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'

            Should -Invoke Invoke-RestMethod -Times 1 -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/accounts/refresh/' -and
                $Method -eq 'Post'
            }
        }

        It 'Should connect with BaseUrl and ApiToken' {
            Connect-EnrolHQ -BaseUrl 'https://custom.domain.com/api/v2/' -ApiToken 'test-token'

            Should -Invoke Invoke-RestMethod -Times 1 -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://custom.domain.com/api/v2/accounts/refresh/'
            }
        }

        It 'Should return connection object with -PassThru' {
            $result = Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token' -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.BaseUrl | Should -Be 'https://testschool.enrolhq.com.au/api/v2/'
            $result.Connected | Should -BeTrue
        }

        It 'Should accept SecureString token' {
            $secureToken = ConvertTo-SecureString 'test-token' -AsPlainText -Force
            { Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken $secureToken } | Should -Not -Throw
        }

        It 'Should send Authorization header with api token on refresh' {
            Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'my-api-token'

            Should -Invoke Invoke-RestMethod -Times 1 -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Headers['Authorization'] -eq 'Token my-api-token'
            }
        }
    }

    Context 'Connecting with environment variables' {

        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ access_token = 'mock-access-token-env' }
            } -ModuleName EnrolHQ.PowerShell
        }

        It 'Should connect using ENROLHQ_INSTANCE and ENROLHQ_API_TOKEN' {
            $env:ENROLHQ_INSTANCE = 'envschool.enrolhq.com.au'
            $env:ENROLHQ_API_TOKEN = 'env-token'

            Connect-EnrolHQ

            Should -Invoke Invoke-RestMethod -Times 1 -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://envschool.enrolhq.com.au/api/v2/accounts/refresh/'
            }
        }

        It 'Should connect using ENROLHQ_BASE_URL and ENROLHQ_API_TOKEN' {
            $env:ENROLHQ_BASE_URL = 'https://staging.example.com/api/v2/'
            $env:ENROLHQ_API_TOKEN = 'env-token'

            Connect-EnrolHQ

            Should -Invoke Invoke-RestMethod -Times 1 -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://staging.example.com/api/v2/accounts/refresh/'
            }
        }

        It 'Should prefer explicit parameters over environment variables' {
            $env:ENROLHQ_INSTANCE = 'envschool.enrolhq.com.au'
            $env:ENROLHQ_API_TOKEN = 'env-token'

            Connect-EnrolHQ -Instance 'explicit.enrolhq.com.au' -ApiToken 'explicit-token'

            Should -Invoke Invoke-RestMethod -Times 1 -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*explicit.enrolhq.com.au*'
            }
        }
    }

    Context 'Authentication failure' {

        It 'Should throw on failed token refresh' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('The remote server returned an error: (401) Unauthorized.')
            } -ModuleName EnrolHQ.PowerShell

            { Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'bad-token' } |
                Should -Throw '*Failed to connect*'
        }

        It 'Should throw on network error' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('Unable to connect to the remote server')
            } -ModuleName EnrolHQ.PowerShell

            { Connect-EnrolHQ -Instance 'unreachable.enrolhq.com.au' -ApiToken 'token' } |
                Should -Throw '*Failed to connect*'
        }

        It 'Should throw when access_token is missing from response' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ some_other_field = 'value' }
            } -ModuleName EnrolHQ.PowerShell

            { Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token' } |
                Should -Throw '*Failed to connect*'
        }
    }
}
