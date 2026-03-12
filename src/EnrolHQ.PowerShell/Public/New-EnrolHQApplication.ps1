function New-EnrolHQApplication {
    <#
    .SYNOPSIS
        Creates a new EnrolHQ application (student profile).
    .DESCRIPTION
        Creates a new student application in EnrolHQ. You can provide data as a
        hashtable or use the explicit parameters for common fields.
    .PARAMETER Data
        A hashtable containing the full application data. This takes precedence
        over explicit parameters. See the EnrolHQ API documentation for the
        CreateStudentProfile schema.
    .PARAMETER FirstName
        Student's first name.
    .PARAMETER LastName
        Student's last name.
    .PARAMETER Dob
        Student's date of birth (YYYY-MM-DD).
    .PARAMETER Gender
        Student's gender code (1=Male, 2=Female, 3=NonBinary, 4=Other).
    .PARAMETER EntryGrade
        Entry grade/year level.
    .PARAMETER EntryYear
        Entry year.
    .PARAMETER ApplicationStatus
        Initial application status. Default: 0 (EnquiryOnline).
    .PARAMETER ParentFirstName
        Primary parent/guardian first name.
    .PARAMETER ParentLastName
        Primary parent/guardian last name.
    .PARAMETER ParentEmail
        Primary parent/guardian email address.
    .PARAMETER ParentPhone
        Primary parent/guardian mobile phone.
    .EXAMPLE
        New-EnrolHQApplication -Data @{
            first_name = 'Jane'
            last_name = 'Smith'
            dob = '2015-03-15'
            entry_grade = 7
            entry_year = 2027
            application_status = 0
            user_parent = @{
                first_name = 'John'
                last_name = 'Smith'
                email = 'john.smith@example.com'
                mobile_phone = '+61400000000'
            }
        }
    .EXAMPLE
        New-EnrolHQApplication -FirstName 'Jane' -LastName 'Smith' -Dob '2015-03-15' `
            -EntryGrade 7 -EntryYear 2027 `
            -ParentFirstName 'John' -ParentLastName 'Smith' `
            -ParentEmail 'john.smith@example.com' -ParentPhone '+61400000000'
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Data')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Data', Position = 0)]
        [hashtable]$Data,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string]$FirstName,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string]$LastName,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$', ErrorMessage = 'Dob must be in YYYY-MM-DD format')]
        [string]$Dob,

        [Parameter(ParameterSetName = 'Explicit')]
        [int]$Gender,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [int]$EntryGrade,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [int]$EntryYear,

        [Parameter(ParameterSetName = 'Explicit')]
        [int]$ApplicationStatus = 0,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string]$ParentFirstName,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string]$ParentLastName,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string]$ParentEmail,

        [Parameter(ParameterSetName = 'Explicit')]
        [string]$ParentPhone
    )

    if ($PSCmdlet.ParameterSetName -eq 'Explicit') {
        $Data = @{
            first_name         = $FirstName
            last_name          = $LastName
            dob                = $Dob
            entry_grade        = $EntryGrade
            entry_year         = $EntryYear
            application_status = $ApplicationStatus
            user_parent        = @{
                first_name   = $ParentFirstName
                last_name    = $ParentLastName
                email        = $ParentEmail
            }
        }
        if ($PSBoundParameters.ContainsKey('Gender')) { $Data['gender'] = $Gender }
        if ($ParentPhone) { $Data['user_parent']['mobile_phone'] = $ParentPhone }
    }

    $description = "$($Data['first_name'] ?? 'Unknown') $($Data['last_name'] ?? 'Unknown')"

    if ($PSCmdlet.ShouldProcess($description, 'Create EnrolHQ Application')) {
        Invoke-EnrolHQRestMethod -Method POST -Endpoint 'applications/' -Body $Data
    }
}
