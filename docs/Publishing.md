# Publishing

This guide covers publishing the EnrolHQ PowerShell module and C# SDK to package feeds,
setting up CI/CD pipelines, and managing versions.

---

## Publishing the PowerShell Module to an Internal Gallery

### 1. Register a Private Feed

Most organisations use [Azure Artifacts](https://dev.azure.com), MyGet, ProGet, or
GitHub Packages as a private NuGet/PowerShell feed.

**Azure Artifacts example:**

```powershell
$feedUrl = 'https://pkgs.dev.azure.com/team-and-systems-hq/_packaging/your-feed/nuget/v2'

# Register as a PowerShell repository
Register-PSRepository -Name 'InternalGallery' `
    -SourceLocation $feedUrl `
    -PublishLocation $feedUrl `
    -InstallationPolicy Trusted
```

### 2. Build and Publish

```powershell
# Build the module (produces publish/EnrolHQ.PowerShell/)
./build.ps1

# Publish to the internal gallery
$apiKey = $env:NUGET_API_KEY   # or retrieve from a secret store
Publish-Module -Path './publish/EnrolHQ.PowerShell' `
               -Repository 'InternalGallery' `
               -NuGetApiKey $apiKey
```

### 3. Verify

```powershell
Find-Module -Name EnrolHQ.PowerShell -Repository InternalGallery
```

---

## Publishing the C# SDK to NuGet

### 1. Pack the Project

```bash
cd src/EnrolHQ.SDK
dotnet pack -c Release -o ../../artifacts
```

This produces `artifacts/EnrolHQ.SDK.<version>.nupkg`.

### 2. Push to a NuGet Feed

**Public NuGet.org:**

```bash
dotnet nuget push artifacts/EnrolHQ.SDK.*.nupkg \
    --api-key $NUGET_API_KEY \
    --source https://api.nuget.org/v3/index.json
```

**Azure Artifacts:**

```bash
dotnet nuget push artifacts/EnrolHQ.SDK.*.nupkg \
    --api-key az \
    --source https://pkgs.dev.azure.com/team-and-systems-hq/_packaging/your-feed/nuget/v3/index.json
```

> When using Azure Artifacts with a PAT, the `--api-key` value is ignored but must
> still be provided. Authenticate via `dotnet nuget add source` with credentials or
> use the Azure Artifacts Credential Provider.

---

## Setting Up Azure Artifacts as a Private Feed

1. In Azure DevOps, go to **Artifacts > Create Feed**.
2. Name the feed (e.g., `enrolhq-packages`), set visibility to *Organisation* or
   *Project*, and enable **upstream sources** if you want to proxy nuget.org.
3. Note the feed URL — you will use it for both NuGet and PowerShell publishing.

### Authenticate from a Dev Machine

```bash
# Install the credential provider (one-time)
dotnet tool install -g artifacts-credprovider

# Add the source
dotnet nuget add source 'https://pkgs.dev.azure.com/team-and-systems-hq/_packaging/your-feed/nuget/v3/index.json' \
    --name 'AzureArtifacts' \
    --username 'your-email' \
    --password '<PAT>' \
    --store-password-in-clear-text
```

### Authenticate from CI/CD

Use the built-in `NuGetAuthenticate` task (Azure Pipelines) or configure a
`NUGET_API_KEY` secret (GitHub Actions).

---

## Versioning Strategy

This project follows [Semantic Versioning (SemVer)](https://semver.org/):

```
MAJOR.MINOR.PATCH[-prerelease]

Examples:
  1.0.0          — first stable release
  1.1.0          — new cmdlets added (backward-compatible)
  1.1.1          — bug fix
  2.0.0          — breaking change (e.g., renamed parameter)
  1.2.0-beta.1   — pre-release for testing
```

### Where versions are defined

| Component        | File                                          | Field              |
|------------------|-----------------------------------------------|--------------------|
| PowerShell module | `src/EnrolHQ.PowerShell/EnrolHQ.PowerShell.psd1` | `ModuleVersion`   |
| C# SDK           | `src/EnrolHQ.SDK/EnrolHQ.SDK.csproj`          | `<Version>`        |

**Rule:** Both components should share the same version number. Update them together.

### Pre-release Workflow

1. Bump the version with a `-beta.N` suffix.
2. Publish to the internal feed.
3. Test in a non-production environment.
4. Remove the suffix and publish the stable release.

---

## CI/CD Pipeline Setup

### GitHub Actions

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Build C# SDK
        run: dotnet build src/EnrolHQ.SDK -c Release

      - name: Run C# tests
        run: dotnet test tests/EnrolHQ.SDK.Tests -c Release --logger trx

      - name: Install Pester
        shell: pwsh
        run: Install-Module Pester -Force -Scope CurrentUser

      - name: Run Pester tests
        shell: pwsh
        run: |
          Import-Module ./src/EnrolHQ.PowerShell
          Invoke-Pester ./tests/EnrolHQ.PowerShell.Tests -CI

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: |
            **/*.trx
            **/testResults.xml

  publish:
    needs: build-and-test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Build and publish
        shell: pwsh
        run: ./build.ps1

      - name: Publish C# SDK to NuGet
        run: |
          dotnet pack src/EnrolHQ.SDK -c Release -o artifacts
          dotnet nuget push artifacts/*.nupkg \
            --api-key ${{ secrets.NUGET_API_KEY }} \
            --source ${{ vars.NUGET_SOURCE }}

      - name: Publish PowerShell module
        shell: pwsh
        run: |
          Register-PSRepository -Name 'InternalGallery' `
              -SourceLocation '${{ vars.PS_FEED_URL }}' `
              -PublishLocation '${{ vars.PS_FEED_URL }}' `
              -InstallationPolicy Trusted
          Publish-Module -Path './publish/EnrolHQ.PowerShell' `
              -Repository 'InternalGallery' `
              -NuGetApiKey '${{ secrets.NUGET_API_KEY }}'
```

### Azure DevOps Pipelines

Create `azure-pipelines.yml`:

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: UseDotNet@2
    inputs:
      version: '8.0.x'

  - script: dotnet build src/EnrolHQ.SDK -c Release
    displayName: 'Build C# SDK'

  - script: dotnet test tests/EnrolHQ.SDK.Tests -c Release --logger trx
    displayName: 'Run C# tests'

  - task: PublishTestResults@2
    inputs:
      testResultsFormat: 'VSTest'
      testResultsFiles: '**/*.trx'

  - pwsh: |
      Install-Module Pester -Force -Scope CurrentUser
      Import-Module ./src/EnrolHQ.PowerShell
      Invoke-Pester ./tests/EnrolHQ.PowerShell.Tests -CI
    displayName: 'Run Pester tests'

  - pwsh: ./build.ps1
    displayName: 'Build module'

  - task: NuGetAuthenticate@1

  - script: |
      dotnet pack src/EnrolHQ.SDK -c Release -o $(Build.ArtifactStagingDirectory)
      dotnet nuget push $(Build.ArtifactStagingDirectory)/*.nupkg \
        --api-key az \
        --source $(NuGetFeedUrl)
    displayName: 'Publish C# SDK'
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
```

---

## Module Signing

For high-security environments, sign the PowerShell module with a code-signing
certificate before publishing.

### 1. Obtain a Code-Signing Certificate

- Use an internal PKI / enterprise CA, or
- Purchase from a public CA (DigiCert, Sectigo, etc.).

### 2. Sign the Module Files

```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object { $_.Subject -like '*Your Org*' }

# Sign all .ps1 and .psm1 files
Get-ChildItem -Path './publish/EnrolHQ.PowerShell' -Recurse -Include *.ps1, *.psm1 |
    ForEach-Object {
        Set-AuthenticodeSignature -FilePath $_.FullName -Certificate $cert -TimestampServer 'http://timestamp.digicert.com'
    }

# Sign the module catalog
New-FileCatalog -Path './publish/EnrolHQ.PowerShell' `
                -CatalogFilePath './publish/EnrolHQ.PowerShell/EnrolHQ.PowerShell.cat' `
                -CatalogVersion 2.0

Set-AuthenticodeSignature -FilePath './publish/EnrolHQ.PowerShell/EnrolHQ.PowerShell.cat' `
                          -Certificate $cert `
                          -TimestampServer 'http://timestamp.digicert.com'
```

### 3. Enforce Execution Policy

On target machines, set the execution policy to require signed scripts:

```powershell
Set-ExecutionPolicy AllSigned -Scope LocalMachine
```

---

**Related guides:**

- [Installation](Installation.md) — installing from a gallery
- [Azure Integration](AzureIntegration.md) — deploying to Azure Automation and Functions
