#Requires -Version 7.0

# Module-scoped connection state
$script:EnrolHQConnection = $null

# Dot-source all class, private, and public function files
$ModuleRoot = $PSScriptRoot

foreach ($scope in @('Classes', 'Private', 'Public')) {
    $path = Join-Path -Path $ModuleRoot -ChildPath $scope
    if (Test-Path -Path $path) {
        Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | ForEach-Object {
            try {
                . $_.FullName
            }
            catch {
                Write-Error "Failed to load $($_.FullName): $_"
            }
        }
    }
}

# Export only Public functions
$publicFunctions = Get-ChildItem -Path (Join-Path $ModuleRoot 'Public') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { $_.BaseName }

if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions
}
