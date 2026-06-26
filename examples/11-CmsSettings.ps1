<#
.SYNOPSIS
    Read the school's CMS / form configuration settings.
.DESCRIPTION
    The cms-settings/ endpoint is read-only and returns a single config object
    covering enquiry & event-booking copy, form labels, terms & conditions,
    parent-dashboard visibility flags, and the policy documents shown to applicants.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'your-token'

$settings = Get-EnrolHQCmsSettings

# Top-level labels used throughout the parent-facing forms
Write-Host "Parent label:        $($settings.parent_label)"
Write-Host "Plural parent label: $($settings.parents_label_plural)"
Write-Host "School level label:  $($settings.school_level_label)"
Write-Host "Student code enabled:$($settings.is_student_code_enabled)"

# Event-booking page copy is nested under its own object
$eventBooking = $settings.event_booking
Write-Host "`nEvent booking page header: $($eventBooking.page_header)"
Write-Host "Make-booking button label: $($eventBooking.make_booking_button_label)"

# Policy documents applicants must agree to (PDFs / links)
$policies = $settings.school_policy_agreement_items
Write-Host "`nPolicy agreement items: $($policies.Count)"
foreach ($item in $policies) {
    $target = if ($item.file_src) { $item.file_src } else { $item.url }
    Write-Host "  - $($item.label): $target"
}

Disconnect-EnrolHQ
