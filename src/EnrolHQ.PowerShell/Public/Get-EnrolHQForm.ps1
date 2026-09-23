function Get-EnrolHQForm {
    <#
    .SYNOPSIS
        Gets a single form by slug, or finds one by title or slug.
    .DESCRIPTION
        -Slug reads the published form from forms/{slug}/. Note this endpoint
        is keyed by the form's `form_slug`, not its UUID.

        -Name is a convenience for looking a form up when you only know its
        name: it lists forms/staff/ and returns the first form whose `title`
        or `form_slug` matches (case-insensitive), or $null if nothing does.
        Use it to get a form's `id` for Get-EnrolHQFormSubmits -Form.
    .PARAMETER Slug
        The form's `form_slug`.
    .PARAMETER Name
        A form title or slug to search for (case-insensitive).
    .EXAMPLE
        Get-EnrolHQForm -Slug 'photo-permission'
    .EXAMPLE
        $form = Get-EnrolHQForm -Name 'Photograph/Video Permission Form'
        Get-EnrolHQFormSubmits -Form $form.id -IsCompleted $true -All
    #>
    [CmdletBinding(DefaultParameterSetName = 'Slug')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Slug', ValueFromPipelineByPropertyName)]
        [Alias('form_slug')]
        [string]$Slug,

        [Parameter(Mandatory, ParameterSetName = 'Name')]
        [string]$Name
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Slug') {
            Write-Verbose "Fetching form forms/$Slug/"
            Invoke-EnrolHQRestMethod -Method GET -Endpoint "forms/$Slug/"
            return
        }

        $needle = $Name.Trim()
        Write-Verbose "Searching forms/staff/ for a form titled or slugged '$needle'"

        $match = Get-EnrolHQAllPages -Endpoint 'forms/staff/' -PageSize 1000 |
            Where-Object {
                ([string]$_.title).Trim() -ieq $needle -or ([string]$_.form_slug).Trim() -ieq $needle
            } |
            Select-Object -First 1

        if ($match) {
            $match
        }
        else {
            Write-Verbose "No form matched '$needle'"
            $null
        }
    }
}
