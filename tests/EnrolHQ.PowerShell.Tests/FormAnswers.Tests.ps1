#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
#Requires -Version 7.0

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '../../src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1'
    Import-Module $ModulePath -Force

    # A form submit shaped like the real staff-submits detail response
    # (mirrors the upstream Python SDK's `_submit()` fixture).
    function New-TestSubmit {
        [PSCustomObject]@{
            id              = 'submit-1'
            completed_at    = '2026-08-20T09:39:21+10:00'
            form_schema     = [PSCustomObject]@{
                id     = 'schema-version-1'   # NOT the form id
                schema = @(
                    [PSCustomObject]@{
                        title    = 'Emergency Contacts'
                        elements = @(
                            [PSCustomObject]@{ name = 'intro'; element_type = 'HTML'; content = '<p>hi</p>' }
                            [PSCustomObject]@{ name = 'contacts_of_emergency_1'; element_type = 'EMERGENCY_CONTACTS' }
                        )
                    }
                    [PSCustomObject]@{
                        title    = 'Photograph/Video Permission Form'
                        elements = @(
                            [PSCustomObject]@{ name = 'group_3_social_media'; label = 'Group 3: Social Media'; element_type = 'RADIO'; options = @('Yes', 'No') }
                            [PSCustomObject]@{ name = 'notes'; label = ' Anything else? '; element_type = 'TEXT' }
                        )
                    }
                )
            }
            initial_payload = [PSCustomObject]@{
                contacts_of_emergency_1 = @([PSCustomObject]@{ first_name = 'Ada' })
                group_3_social_media    = ''
                notes                   = ''
            }
            payload         = [PSCustomObject]@{ group_3_social_media = 'Yes' }
        }
    }
}

AfterAll {
    Remove-Module EnrolHQ.PowerShell -Force -ErrorAction SilentlyContinue
}

Describe 'Get-EnrolHQFormAnswers' {

    BeforeAll {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ access_token = 'mock-access-token' }
        } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*accounts/refresh/*' }
        Connect-EnrolHQ -Instance 'testschool.enrolhq.com.au' -ApiToken 'test-token'
    }

    AfterAll { Disconnect-EnrolHQ }

    Context 'Offline flattening (-Submit)' {
        It 'Labels answers in form order and skips HTML content elements' {
            $answers = @(Get-EnrolHQFormAnswers -Submit (New-TestSubmit))

            $answers.name | Should -Be @('contacts_of_emergency_1', 'group_3_social_media', 'notes')
            $answers[0].PSObject.TypeNames[0] | Should -Be 'EnrolHQ.FormAnswer'

            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -notlike '*accounts/refresh/*'
            }
        }

        It 'Overlays payload on initial_payload and carries section + label' {
            $byName = @{}
            Get-EnrolHQFormAnswers -Submit (New-TestSubmit) | ForEach-Object { $byName[$_.name] = $_ }

            $byName['group_3_social_media'].value | Should -Be 'Yes'
            $byName['group_3_social_media'].label | Should -Be 'Group 3: Social Media'
            $byName['group_3_social_media'].section | Should -Be 'Photograph/Video Permission Form'
            $byName['group_3_social_media'].element_type | Should -Be 'RADIO'

            # initial_payload fills in what payload doesn't carry
            $byName['contacts_of_emergency_1'].value[0].first_name | Should -Be 'Ada'
            $byName['contacts_of_emergency_1'].is_profile_backed | Should -BeTrue
            $byName['notes'].is_profile_backed | Should -BeFalse
            $byName['notes'].label | Should -Be 'Anything else?'   # stripped
        }

        It 'Accepts pipeline input' {
            $answers = @(New-TestSubmit | Get-EnrolHQFormAnswers)
            $answers | Should -HaveCount 3
        }

        It 'Handles a missing schema and null payloads' {
            @(Get-EnrolHQFormAnswers -Submit ([PSCustomObject]@{})) | Should -HaveCount 0
            @(Get-EnrolHQFormAnswers -Submit ([PSCustomObject]@{
                form_schema = [PSCustomObject]@{ schema = @() }; payload = $null; initial_payload = $null
            })) | Should -HaveCount 0
        }

        It 'Returns only choice elements with -ConsentsOnly' {
            $consents = @(Get-EnrolHQFormAnswers -Submit (New-TestSubmit) -ConsentsOnly)

            $consents | Should -HaveCount 1
            $consents[0].name | Should -Be 'group_3_social_media'
            $consents[0].label | Should -Be 'Group 3: Social Media'
            $consents[0].value | Should -Be 'Yes'
        }
    }

    Context 'By submit id' {
        It 'Fetches forms/staff-submits/{id}/ and flattens it' {
            Mock Invoke-RestMethod { New-TestSubmit } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/submit-1/*'
            }

            $answers = @(Get-EnrolHQFormAnswers -SubmitId 'submit-1')

            $answers | Should -HaveCount 3
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/forms/staff-submits/submit-1/'
            }
        }

        It 'Treats a piped string as a submit id and fetches it' {
            Mock Invoke-RestMethod { New-TestSubmit } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/submit-1/*'
            }

            $answers = @('submit-1' | Get-EnrolHQFormAnswers)

            $answers | Should -HaveCount 3
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -eq 'https://testschool.enrolhq.com.au/api/v2/forms/staff-submits/submit-1/'
            }
        }
    }

    Context 'By application' {
        BeforeEach {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    custom_form_submits = @([PSCustomObject]@{ id = 'submit-1'; form = 'form-a' })
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*applications/app-1/*' }

            Mock Invoke-RestMethod { New-TestSubmit } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/*'
            }
        }

        It 'Adds submit_id, form_id, application_id and completed_at to every answer' {
            $answers = @(Get-EnrolHQFormAnswers -ApplicationId 'app-1')

            $answers.name | Should -Be @('contacts_of_emergency_1', 'group_3_social_media', 'notes')
            $answers | ForEach-Object {
                $_.submit_id | Should -Be 'submit-1'
                $_.form_id | Should -Be 'form-a'
                $_.application_id | Should -Be 'app-1'
                $_.completed_at | Should -Be '2026-08-20T09:39:21+10:00'
            }
        }

        It 'Passes -Form through to the submit lookup' {
            @(Get-EnrolHQFormAnswers -ApplicationId 'app-1' -Form 'form-b') | Should -HaveCount 0
            Should -Not -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/*'
            }
        }
    }

    Context 'Bulk by form' {
        BeforeEach {
            # The submits list carries student_profile but no submit id, so the
            # cmdlet must resolve ids via the application detail.
            Mock Invoke-RestMethod {
                $profile = [PSCustomObject]@{ id = 'app-1'; first_name = 'Ada'; last_name = 'L' }
                [PSCustomObject]@{
                    count = 3; next = $null
                    results = @(
                        [PSCustomObject]@{ form_id = 'form-a'; student_profile = $profile }
                        [PSCustomObject]@{ form_id = 'form-a'; student_profile = $profile }   # same profile
                        [PSCustomObject]@{ form_id = 'form-a'; student_profile = [PSCustomObject]@{} }  # no id -> skipped
                    )
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*forms/staff-submits/?*' }

            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    custom_form_submits = @([PSCustomObject]@{ id = 'submit-1'; form = 'form-a' })
                }
            } -ModuleName EnrolHQ.PowerShell -ParameterFilter { $Uri -like '*applications/app-1/*' }

            Mock Invoke-RestMethod { New-TestSubmit } -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/submit-1/*'
            }
        }

        It 'Dedupes profiles, skips id-less rows and attaches student_profile' {
            $answers = @(Get-EnrolHQFormAnswers -Form 'form-a' -IsCompleted $true)

            # One submit's worth of answers: the duplicate profile and the id-less row are both skipped.
            $answers | Should -HaveCount 3
            $answers[0].student_profile.last_name | Should -Be 'L'
            $answers[0].submit_id | Should -Be 'submit-1'
            $answers[0].application_id | Should -Be 'app-1'

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*applications/app-1/*'
            }
            Should -Invoke Invoke-RestMethod -ModuleName EnrolHQ.PowerShell -ParameterFilter {
                $Uri -like '*forms/staff-submits/?*' -and $Uri -like '*form=form-a*' -and $Uri -like '*is_completed=true*'
            }
        }

        It 'Combines -ConsentsOnly with bulk mode' {
            $consents = @(Get-EnrolHQFormAnswers -Form 'form-a' -ConsentsOnly)
            $consents | Should -HaveCount 1
            $consents[0].label | Should -Be 'Group 3: Social Media'
            $consents[0].student_profile.first_name | Should -Be 'Ada'
        }
    }
}
