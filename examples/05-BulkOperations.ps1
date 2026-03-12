<#
.SYNOPSIS
    Bulk operations on EnrolHQ applications.
.DESCRIPTION
    WARNING: Bulk operations affect multiple records. Test carefully.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'yourschool' -ApiToken 'your-token'

# --- Bulk note ---
Invoke-EnrolHQBulkOperation -Operation Note `
    -Data @{ text = 'Reminder: enrolment documents due end of term.' } `
    -Filter @{ entry_year = 2026; entry_grade = 7 }
Write-Host 'Bulk note added'

# --- Change status ---
Invoke-EnrolHQBulkOperation -Operation ChangeStatus `
    -Data @{ application_status = [EnrolHQStatus]::Eoi } `
    -Filter @{ id__in = 'uuid1,uuid2,uuid3' }

# --- Bulk email ---
Invoke-EnrolHQBulkOperation -Operation SendEmail -Data @{
    from_email                    = 'registrar@school.edu.au'
    subject_template              = 'Welcome to our school'
    html_template                 = '<p>Dear parent, thank you for your enquiry.</p>'
    recipient_type                = 'CARERS'
    is_base_render_needed         = $true
    is_single_email_per_recipient = $true
    cc = @(); bcc = @(); attachments = @()
    logo_email_top_src = ''; logo_email_bottom_src = ''
} -Filter @{ entry_year = 2026; application_statuses = '0' }

Disconnect-EnrolHQ
