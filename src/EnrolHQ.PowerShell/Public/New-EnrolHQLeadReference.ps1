function New-EnrolHQLeadReference {
    <#
    .SYNOPSIS
        Creates a new lead reference and returns it (with its server-assigned id).
    .DESCRIPTION
        Lead references have no dedicated write endpoint - they live on the
        school settings object. This cmdlet round-trips school/:
        GET -> append to `lead_references` -> PUT, then re-reads
        lead-references/ and returns the new record.

        Fails (without writing anything) if a lead reference with the same
        slug already exists.
    .PARAMETER Name
        Display name for the reference.
    .PARAMETER Slug
        URL slug. Defaults to a slugified Name (lower-case, non-alphanumerics
        collapsed to '-').
    .PARAMETER ConfirmationRedirectUrl
        Where the public form redirects after submission. Empty (default) uses
        the standard confirmation page.
    .EXAMPLE
        $ref = New-EnrolHQLeadReference -Name 'Open Day 2027'
        $ref.slug   # open-day-2027
        $ref.id     # use as the `reference` field of a lead
    .EXAMPLE
        New-EnrolHQLeadReference -Name 'SDK Example Reference' -Slug 'sdk-example-reference'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter()]
        [string]$Slug,

        [Parameter()]
        [string]$ConfirmationRedirectUrl = ''
    )

    if (-not $Slug) {
        $Slug = ([regex]::Replace($Name.ToLowerInvariant(), '[^a-z0-9]+', '-')).Trim('-')
    }

    Write-Verbose "Reading school settings to add lead reference '$Slug'"
    # -ErrorAction Stop throughout: a failed read or write must surface as
    # itself, not as a misleading 'not found after saving' at the end.
    $school = Invoke-EnrolHQRestMethod -Method GET -Endpoint 'school/' -ErrorAction Stop

    $existing = @()
    if ($school -and $school.PSObject.Properties['lead_references'] -and $school.lead_references) {
        $existing = @($school.lead_references)
    }

    if ($existing | Where-Object { $_.slug -eq $Slug }) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new("A lead reference with slug '$Slug' already exists"),
                'EnrolHQ.DuplicateLeadReference',
                [System.Management.Automation.ErrorCategory]::ResourceExists,
                $Slug
            )
        )
    }

    if (-not $PSCmdlet.ShouldProcess($Name, 'Create EnrolHQ Lead Reference')) {
        return
    }

    $newReference = [PSCustomObject]@{
        name                     = $Name
        slug                     = $Slug
        confirmation_redirect_url = $ConfirmationRedirectUrl
        is_removable             = $true
    }

    $school | Add-Member -NotePropertyName 'lead_references' -NotePropertyValue ($existing + @($newReference)) -Force

    Write-Verbose "Saving school settings with new lead reference '$Slug'"
    Invoke-EnrolHQRestMethod -Method PUT -Endpoint 'school/' -Body $school -ErrorAction Stop | Out-Null

    $created = Get-EnrolHQLeadReferences -ErrorAction Stop | Where-Object { $_.slug -eq $Slug } | Select-Object -First 1
    if (-not $created) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new("Lead reference '$Slug' was not found after saving school settings"),
                'EnrolHQ.LeadReferenceNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Slug
            )
        )
    }

    $created
}
