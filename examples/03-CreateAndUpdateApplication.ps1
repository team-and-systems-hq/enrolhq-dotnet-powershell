<#
.SYNOPSIS
    Create and update applications in EnrolHQ.
.DESCRIPTION
    WARNING: These examples create and modify real data. Use on a test instance first.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'yourschool' -ApiToken 'your-token'

# --- Create with hashtable ---
$newApp = New-EnrolHQApplication -Data @{
    first_name         = 'Jane'
    last_name          = 'Doe'
    dob                = '2015-03-15'
    gender             = 2  # Female
    entry_grade        = 7
    entry_year         = 2027
    application_status = 0  # EnquiryOnline
    user_parent        = @{
        first_name   = 'John'
        last_name    = 'Doe'
        email        = 'john.doe@example.com'
        mobile_phone = '+61400000000'
    }
}
Write-Host "Created: $($newApp.id) - $($newApp.first_name) $($newApp.last_name)"

# --- Create with explicit parameters ---
$newApp2 = New-EnrolHQApplication `
    -FirstName 'Bob' -LastName 'Smith' -Dob '2016-01-20' `
    -Gender 1 -EntryGrade 5 -EntryYear 2027 `
    -ParentFirstName 'Sarah' -ParentLastName 'Smith' `
    -ParentEmail 'sarah.smith@example.com' -ParentPhone '+61400111222'
Write-Host "Created: $($newApp2.id)"

# --- Update (GET -> modify -> PUT) ---
$app = Get-EnrolHQApplication -Id $newApp.id
$app.preferred_name = 'Jenny'
$app.entry_grade = 8
$updated = Set-EnrolHQApplication -Id $newApp.id -Data $app
Write-Host "Updated preferred_name=$($updated.preferred_name), entry_grade=$($updated.entry_grade)"

Disconnect-EnrolHQ
