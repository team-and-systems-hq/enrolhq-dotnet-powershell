#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Form definition cmdlets' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Get-EnrolHQForms' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count = 2; next = $null
                    results = @(
                        [PSCustomObject]@{ id = '1'; title = 'Enquiry'; form_slug = 'stub-enquiry-form'; kind = 'ENQUIRY' }
                        [PSCustomObject]@{ id = '2'; title = 'Photo Permission'; form_slug = 'photo-perm'; kind = 'CUSTOM' }
                    )
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
        }

        It 'Calls forms/staff/ by default' {
            $forms = Get-EnrolHQForms -All
            $forms | Should -HaveCount 2
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff/?*'
            }
        }

        It 'Calls forms/ (not forms/staff/) with -Published' {
            Get-EnrolHQForms -Published -All | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like 'https://testschool.enrolhq.com.au/api/v2/forms/?*' -and $Uri -notlike '*forms/staff/*'
            }
        }

        It 'Returns a page object without -All' {
            $page = Get-EnrolHQForms -PageSize 50
            $page.Count | Should -Be 2
            $page.Results[1].kind | Should -Be 'CUSTOM'
        }
    }

    Context 'Get-EnrolHQForm' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = '2'; title = 'Photo Permission'; form_slug = 'photo-perm'; allowed_entry_years = @(2027) }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*forms/photo-perm/*' }

            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count = 2; next = $null
                    results = @(
                        [PSCustomObject]@{ id = '1'; title = 'Enquiry'; form_slug = 'stub-enquiry-form' }
                        [PSCustomObject]@{ id = '2'; title = 'Photo Permission'; form_slug = 'photo-perm' }
                    )
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*forms/staff/*' }
        }

        It 'Reads forms/{slug}/ with -Slug' {
            $form = Get-EnrolHQForm -Slug 'photo-perm'
            $form.id | Should -Be '2'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/forms/photo-perm/'
            }
        }

        It 'Finds by title case-insensitively with -Name' {
            (Get-EnrolHQForm -Name 'photo permission').id | Should -Be '2'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff/*' -and $Uri -like '*page_size=1000*'
            }
        }

        It 'Finds by slug case-insensitively with -Name' {
            (Get-EnrolHQForm -Name 'PHOTO-PERM').id | Should -Be '2'
        }

        It 'Returns $null when nothing matches' {
            Get-EnrolHQForm -Name 'nope' | Should -BeNullOrEmpty
        }
    }
}
