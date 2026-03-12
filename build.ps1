#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build, test, and package the EnrolHQ PowerShell Toolkit.

.DESCRIPTION
    This script performs the following steps:
      1. Builds the C# SDK (dotnet build)
      2. Runs C# unit tests (dotnet test)
      3. Runs PowerShell Pester tests
      4. Publishes the PowerShell module to a staging directory
      5. Creates a distributable zip archive

.PARAMETER Configuration
    Build configuration. Default: Release.

.PARAMETER SkipTests
    Skip all test steps.

.PARAMETER SkipCSharpTests
    Skip C# (xUnit) tests only.

.PARAMETER SkipPesterTests
    Skip PowerShell (Pester) tests only.

.PARAMETER OutputPath
    Directory for build artefacts. Default: ./publish

.EXAMPLE
    ./build.ps1

.EXAMPLE
    ./build.ps1 -Configuration Debug -SkipPesterTests
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',

    [switch] $SkipTests,
    [switch] $SkipCSharpTests,
    [switch] $SkipPesterTests,

    [string] $OutputPath = (Join-Path $PSScriptRoot 'publish')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$sdkProject      = Join-Path $PSScriptRoot 'src' 'EnrolHQ.SDK'
$sdkTestProject  = Join-Path $PSScriptRoot 'tests' 'EnrolHQ.SDK.Tests'
$psModuleSource  = Join-Path $PSScriptRoot 'src' 'EnrolHQ.PowerShell'
$pesterTestPath  = Join-Path $PSScriptRoot 'tests' 'EnrolHQ.PowerShell.Tests'
$moduleOutput    = Join-Path $OutputPath 'EnrolHQ.PowerShell'
$testResultsDir  = Join-Path $PSScriptRoot 'TestResults'

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
function Write-Step {
    param([string] $Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Step 1 — Build the C# SDK
# ---------------------------------------------------------------------------
Write-Step 'Step 1: Building C# SDK'

if (Test-Path $sdkProject) {
    dotnet build $sdkProject -c $Configuration --nologo
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'C# SDK build failed.'
    }
    Write-Host 'C# SDK build succeeded.' -ForegroundColor Green
} else {
    Write-Warning "SDK project not found at $sdkProject — skipping build."
}

# ---------------------------------------------------------------------------
# Step 2 — Run C# tests
# ---------------------------------------------------------------------------
if (-not $SkipTests -and -not $SkipCSharpTests) {
    Write-Step 'Step 2: Running C# tests'

    if (Test-Path $sdkTestProject) {
        if (-not (Test-Path $testResultsDir)) {
            New-Item -ItemType Directory -Path $testResultsDir -Force | Out-Null
        }

        dotnet test $sdkTestProject -c $Configuration --nologo `
            --logger "trx;LogFileName=sdk-tests.trx" `
            --results-directory $testResultsDir

        if ($LASTEXITCODE -ne 0) {
            Write-Error 'C# tests failed.'
        }
        Write-Host 'C# tests passed.' -ForegroundColor Green
    } else {
        Write-Warning "Test project not found at $sdkTestProject — skipping."
    }
} else {
    Write-Step 'Step 2: C# tests — SKIPPED'
}

# ---------------------------------------------------------------------------
# Step 3 — Run Pester tests
# ---------------------------------------------------------------------------
if (-not $SkipTests -and -not $SkipPesterTests) {
    Write-Step 'Step 3: Running Pester tests'

    if (Test-Path $pesterTestPath) {
        # Ensure Pester 5+ is available
        if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0' })) {
            Write-Host 'Installing Pester 5...' -ForegroundColor Yellow
            Install-Module Pester -MinimumVersion 5.0 -Force -Scope CurrentUser -SkipPublisherCheck
        }

        Import-Module Pester -MinimumVersion 5.0

        # Import the module under test
        Import-Module $psModuleSource -Force

        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $pesterTestPath
        $pesterConfig.Run.Exit = $false
        $pesterConfig.TestResult.Enabled = $true
        $pesterConfig.TestResult.OutputPath = (Join-Path $testResultsDir 'pester-results.xml')
        $pesterConfig.TestResult.OutputFormat = 'NUnitXml'
        $pesterConfig.Output.Verbosity = 'Detailed'

        $result = Invoke-Pester -Configuration $pesterConfig

        if ($result.FailedCount -gt 0) {
            Write-Error "Pester tests failed: $($result.FailedCount) failure(s)."
        }
        Write-Host 'Pester tests passed.' -ForegroundColor Green
    } else {
        Write-Warning "Pester test path not found at $pesterTestPath — skipping."
    }
} else {
    Write-Step 'Step 3: Pester tests — SKIPPED'
}

# ---------------------------------------------------------------------------
# Step 4 — Publish the PowerShell module to a staging directory
# ---------------------------------------------------------------------------
Write-Step 'Step 4: Publishing module to staging directory'

if (Test-Path $moduleOutput) {
    Remove-Item -Recurse -Force $moduleOutput
}
New-Item -ItemType Directory -Path $moduleOutput -Force | Out-Null

# Copy module files
$filesToCopy = @('*.psd1', '*.psm1')
Get-ChildItem -Path $psModuleSource -Include $filesToCopy -Recurse |
    Copy-Item -Destination $moduleOutput

# Copy sub-directories (Public, Private, Classes)
foreach ($subDir in @('Public', 'Private', 'Classes')) {
    $sourceSub = Join-Path $psModuleSource $subDir
    if (Test-Path $sourceSub) {
        $destSub = Join-Path $moduleOutput $subDir
        Copy-Item -Path $sourceSub -Destination $destSub -Recurse
    }
}

# Copy the C# SDK assembly if it was built
$sdkDll = Join-Path $sdkProject 'bin' $Configuration 'net8.0' 'EnrolHQ.SDK.dll'
if (Test-Path $sdkDll) {
    $libDir = Join-Path $moduleOutput 'lib'
    New-Item -ItemType Directory -Path $libDir -Force | Out-Null

    # Copy the SDK DLL and its dependencies
    $sdkBinDir = Split-Path $sdkDll
    Get-ChildItem -Path $sdkBinDir -Filter '*.dll' |
        Copy-Item -Destination $libDir
}

Write-Host "Module published to: $moduleOutput" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 5 — Create a zip archive for distribution
# ---------------------------------------------------------------------------
Write-Step 'Step 5: Creating distribution zip'

$zipPath = Join-Path $OutputPath 'EnrolHQ.PowerShell.zip'
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

Compress-Archive -Path $moduleOutput -DestinationPath $zipPath -CompressionLevel Optimal

$zipSize = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
Write-Host "Distribution archive created: $zipPath ($zipSize KB)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Step 'Build complete'
Write-Host "  Module directory : $moduleOutput"
Write-Host "  Distribution zip : $zipPath"
Write-Host "  Test results     : $testResultsDir"
Write-Host ''
