#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Get-EnrolHQCmsSettings' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    BeforeEach {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{
                parent_label  = 'Parent'
                event_booking = [PSCustomObject]@{ page_header = 'Book a tour' }
                school_policy_agreement_items = @(
                    [PSCustomObject]@{ label = 'Privacy Policy'; file_src = 'privacy.pdf' }
                )
            }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
    }

    It 'Calls the cms-settings/ endpoint' {
        Get-EnrolHQCmsSettings | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
            $Uri -like '*cms-settings/*'
        }
    }

    It 'Returns the configuration object' {
        $settings = Get-EnrolHQCmsSettings
        $settings.parent_label | Should -Be 'Parent'
        $settings.event_booking.page_header | Should -Be 'Book a tour'
        $settings.school_policy_agreement_items | Should -HaveCount 1
    }
}
