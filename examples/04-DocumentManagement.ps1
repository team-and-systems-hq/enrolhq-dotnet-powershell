<#
.SYNOPSIS
    Upload, list, download, and delete documents in EnrolHQ.
.DESCRIPTION
    WARNING: Upload and delete operations affect real data.
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'your-token'

$studentId = 'your-student-profile-uuid'

# --- List documents ---
$docs = Get-EnrolHQDocuments -StudentProfileId $studentId
Write-Host "Documents for $studentId : $($docs.Count) found"
foreach ($doc in $docs) {
    Write-Host "  [$($doc.group_kind)] $($doc.filename) (verified: $($doc.is_verified))"
}

# --- Upload a document ---
$uploaded = Send-EnrolHQDocument `
    -StudentProfileId $studentId `
    -FilePath './report.pdf' `
    -GroupKind 'SCHOOL_REPORT'
Write-Host "`nUploaded: $($uploaded.filename) (ID: $($uploaded.id))"

# --- Download ---
if ($docs.Count -gt 0) {
    $file = Save-EnrolHQDocument -DocumentUrl $docs[0].file -DestinationPath "./downloads/$($docs[0].filename)"
    Write-Host "Downloaded to: $($file.FullName)"
}

# --- Delete (requires confirmation) ---
# Remove-EnrolHQDocument -Id $uploaded.id

Disconnect-EnrolHQ
