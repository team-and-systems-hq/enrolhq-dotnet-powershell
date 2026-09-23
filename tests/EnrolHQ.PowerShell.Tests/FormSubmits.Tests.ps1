#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Form submit cmdlets' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Get-EnrolHQFormSubmits' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    count = 3; next = $null
                    results = @([PSCustomObject]@{ form_id = 'form-a'; student_profile = [PSCustomObject]@{ id = 'app-1' } })
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
        }

        It 'Calls forms/staff-submits/ and passes the filters through' {
            Get-EnrolHQFormSubmits -Form 'form-a' -EntryYear 2027 -IsCompleted $true -All | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/?*' -and
                $Uri -like '*form=form-a*' -and
                $Uri -notlike '*form_id=*' -and
                $Uri -like '*entry_year=2027*' -and
                $Uri -like '*is_completed=true*'
            }
        }

        It 'Joins application statuses with commas' {
            Get-EnrolHQFormSubmits -ApplicationStatus 4, 7 -PageSize 1 | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*application_statuses=4%2C7*' -or $Uri -like '*application_statuses=4,7*'
            }
        }

        It 'Keeps -ApplicationStatus 0 instead of dropping it as falsy' {
            Get-EnrolHQFormSubmits -ApplicationStatus 0 -PageSize 1 | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*application_statuses=0*'
            }
        }

        It 'Exposes the total count on the page object' {
            (Get-EnrolHQFormSubmits -Form 'form-a' -IsCompleted $false -PageSize 1).Count | Should -Be 3
        }
    }

    Context 'Get-EnrolHQFormSubmit' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    custom_form_submits = @(
                        [PSCustomObject]@{ id = 'submit-1'; form = 'form-a'; completed_at = 'x' }
                        [PSCustomObject]@{ id = 'submit-2'; form = 'form-b'; completed_at = 'y' }
                    )
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*applications/app-1/*' }

            Mock Invoke-RestMethod {
                $id = ($Uri -split '/')[-2]
                [PSCustomObject]@{
                    id           = $id
                    completed_at = '2026-08-20T09:39:21+10:00'
                    form_schema  = [PSCustomObject]@{ id = 'schema-version-1' }
                    payload      = [PSCustomObject]@{ q = 'Yes' }
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*forms/staff-submits/*' }
        }

        It 'Reads forms/staff-submits/{id}/ with -Id' {
            $submit = Get-EnrolHQFormSubmit -Id 'submit-1'
            $submit.id | Should -Be 'submit-1'
            $submit.payload.q | Should -Be 'Yes'
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/forms/staff-submits/submit-1/'
            }
        }

        It 'Resolves submits via the application detail and annotates form_id / application_id' {
            $submits = @(Get-EnrolHQFormSubmit -ApplicationId 'app-1')

            $submits | Should -HaveCount 2
            $submits.form_id | Should -Be @('form-a', 'form-b')
            $submits.application_id | Should -Be @('app-1', 'app-1')
            $submits[0].id | Should -Be 'submit-1'

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/applications/app-1/'
            }
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/submit-1/*'
            }
        }

        It 'Fetches only the matching submit when -Form is given' {
            $submits = @(Get-EnrolHQFormSubmit -ApplicationId 'app-1' -Form 'form-b')

            $submits | Should -HaveCount 1
            $submits[0].form_id | Should -Be 'form-b'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/*'
            }
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/submit-2/*'
            }
        }
    }

    Context 'Set-EnrolHQFormSubmit' {
        It 'PUTs { payload } to forms/staff-submits/{id}/' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'submit-1' }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            Set-EnrolHQFormSubmit -Id 'submit-1' -Payload @{ group_3_social_media = 'No' } -Confirm:$false | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/forms/staff-submits/submit-1/' -and
                $Method -eq 'PUT' -and
                $Body -like '*"payload":{*' -and
                $Body -like '*group_3_social_media*'
            }
        }

        It 'Supports -WhatIf' {
            Mock Invoke-RestMethod {} -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
            Set-EnrolHQFormSubmit -Id 'submit-1' -Payload @{} -WhatIf
            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Method -eq 'PUT' }
        }
    }

    Context 'Unlock-EnrolHQFormSubmit' {
        It 'POSTs to forms/staff-submits/{id}/re_open/' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{ id = 'submit-1'; completed_at = $null }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            Unlock-EnrolHQFormSubmit -Id 'submit-1' -Confirm:$false | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/forms/staff-submits/submit-1/re_open/' -and
                $Method -eq 'POST'
            }
        }

        It 'Supports -WhatIf' {
            Mock Invoke-RestMethod {} -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }
            Unlock-EnrolHQFormSubmit -Id 'submit-1' -WhatIf
            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Method -eq 'POST' }
        }
    }

    Context 'Export-EnrolHQFormSubmits' {
        It 'Downloads forms/staff-submits/export/ to the destination file with the filters' {
            Mock Invoke-RestMethod {
                Set-Content -Path $OutFile -Value 'profile.first_name,payload.q'
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $dest = Join-Path $TestDrive 'exports/consents.csv'
            $file = Export-EnrolHQFormSubmits -DestinationPath $dest -Form 'form-a' -IsCompleted $true

            $file.FullName | Should -Be (Get-Item $dest).FullName
            Get-Content $dest | Should -Be 'profile.first_name,payload.q'

            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/export/?*' -and
                $Uri -like '*form=form-a*' -and
                $Uri -like '*is_completed=true*' -and
                $Method -eq 'GET' -and
                $OutFile -eq $dest
            }
        }

        It 'Keeps -ApplicationStatus 0 instead of dropping it as falsy' {
            Mock Invoke-RestMethod {
                Set-Content -Path $OutFile -Value 'x'
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            Export-EnrolHQFormSubmits -DestinationPath (Join-Path $TestDrive 'status0.csv') -ApplicationStatus 0 | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*application_statuses=0*'
            }
        }

        It 'Throws on a failed download instead of returning a stale file' {
            Mock Invoke-RestMethod {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new(
                    'Forbidden', [System.Net.Http.HttpResponseMessage]::new(403))
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -notlike '*accounts/refresh/*' }

            $dest = Join-Path $TestDrive 'stale.csv'
            Set-Content -Path $dest -Value 'yesterday'

            { Export-EnrolHQFormSubmits -DestinationPath $dest -Form 'form-a' } | Should -Throw
            Get-Content $dest | Should -Be 'yesterday'
        }
    }
}
