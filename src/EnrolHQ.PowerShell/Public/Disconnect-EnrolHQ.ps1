function Disconnect-EnrolHQ {
    <#
    .SYNOPSIS
        Disconnects from the EnrolHQ API.
    .DESCRIPTION
        Clears the stored EnrolHQ connection from module scope.
        Subsequent API calls will fail until Connect-EnrolHQ is called again.
    .EXAMPLE
        Disconnect-EnrolHQ
    #>
    [CmdletBinding()]
    param()

    if ($script:EnrolHQConnection) {
        $script:EnrolHQConnection = $null
        Write-Verbose 'Disconnected from EnrolHQ'
    }
    else {
        Write-Verbose 'No active EnrolHQ connection to disconnect'
    }
}
