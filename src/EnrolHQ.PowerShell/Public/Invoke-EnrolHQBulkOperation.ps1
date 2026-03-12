function Invoke-EnrolHQBulkOperation {
    <#
    .SYNOPSIS
        Executes a bulk operation on EnrolHQ applications.
    .DESCRIPTION
        Performs bulk actions on applications matching the specified filter criteria.
        These operations affect multiple records at once — use with caution.
    .PARAMETER Operation
        The bulk operation to perform.
    .PARAMETER Data
        Operation-specific data as a hashtable.
    .PARAMETER Filter
        Filter criteria to select target applications (passed as query parameters).
    .EXAMPLE
        # Add a note to all 2026 Year 7 applications
        Invoke-EnrolHQBulkOperation -Operation Note `
            -Data @{ text = 'Reminder: documents due' } `
            -Filter @{ entry_year = 2026; entry_grade = 7 }
    .EXAMPLE
        # Change status to EOI for selected applications
        Invoke-EnrolHQBulkOperation -Operation ChangeStatus `
            -Data @{ application_status = 2 } `
            -Filter @{ id__in = 'uuid1,uuid2,uuid3' }
    .EXAMPLE
        # Send bulk email
        Invoke-EnrolHQBulkOperation -Operation SendEmail -Data @{
            from_email = 'registrar@school.edu.au'
            subject_template = 'Welcome to our school'
            html_template = '<p>Dear parent, ...</p>'
            recipient_type = 'CARERS'
            is_base_render_needed = $true
            cc = @()
            bcc = @()
            attachments = @()
            is_single_email_per_recipient = $true
            logo_email_top_src = ''
            logo_email_bottom_src = ''
        } -Filter @{ entry_year = 2026 }
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet(
            'SendEmail',
            'SendSms',
            'Note',
            'EnrolmentInvite',
            'Close',
            'Reopen',
            'MakeOffer',
            'ChangeCampus',
            'ManualPayments',
            'ChangeStatus',
            'DeleteProfiles'
        )]
        [string]$Operation,

        [Parameter()]
        [hashtable]$Data = @{},

        [Parameter()]
        [hashtable]$Filter = @{}
    )

    $endpointMap = @{
        SendEmail       = 'applications-list/bulk_send_email/'
        SendSms         = 'applications-list/bulk_send_sms/'
        Note            = 'applications-list/bulk_note/'
        EnrolmentInvite = 'applications-list/bulk_enrolment_invite/'
        Close           = 'applications-list/bulk_close/'
        Reopen          = 'applications-list/bulk_reopen/'
        MakeOffer       = 'applications-list/bulk_make_offer/enrolment_offer/'
        ChangeCampus    = 'applications-list/bulk_change_campus/'
        ManualPayments  = 'applications-list/bulk_make_manual_payments/'
        ChangeStatus    = 'applications-list/change_status/'
        DeleteProfiles  = 'applications-list/delete-profiles/'
    }

    $endpoint = $endpointMap[$Operation]

    if ($PSCmdlet.ShouldProcess("$Operation on filtered applications", 'Execute Bulk Operation')) {
        $params = @{
            Method   = 'POST'
            Endpoint = $endpoint
        }

        if ($Data.Count -gt 0) { $params['Body'] = $Data }
        if ($Filter.Count -gt 0) { $params['QueryParameters'] = $Filter }

        Invoke-EnrolHQRestMethod @params
    }
}
