# Installation Guide

This guide covers installing both the **EnrolHQ PowerShell module** and the underlying **C# SDK**.

---

## Prerequisites

| Component            | Requirement                     |
|----------------------|---------------------------------|
| PowerShell module    | PowerShell 7.0 or later         |
| C# SDK (development) | .NET 8 SDK                     |
| Operating system     | Windows, macOS, or Linux        |

Verify your PowerShell version:

```powershell
$PSVersionTable.PSVersion
```

Verify the .NET SDK (only needed if you are building or extending the C# SDK):

```bash
dotnet --version
```

---

## Installing the PowerShell Module

### Option A — Import from Local Source

Clone the repository and import the module directly:

```powershell
git clone https://github.com/team-and-systems-hq/enrolhq-dotnet-powershell.git
Import-Module ./enrolhq-dotnet-powershell/src/EnrolHQ.PowerShell
```

This is the fastest way to get started during development or evaluation.

### Option B — Install from an Internal PowerShell Gallery

If your organisation hosts a private NuGet feed (Azure Artifacts, MyGet, ProGet, etc.),
register it as a PowerShell repository first:

```powershell
# Register the private feed (one-time setup)
Register-PSRepository -Name 'InternalGallery' `
    -SourceLocation 'https://pkgs.dev.azure.com/team-and-systems-hq/_packaging/your-feed/nuget/v2' `
    -InstallationPolicy Trusted

# Install the module
Install-Module -Name EnrolHQ.PowerShell -Repository InternalGallery
```

To update later:

```powershell
Update-Module -Name EnrolHQ.PowerShell
```

### Option C — Azure Automation

Azure Automation supports two approaches:

1. **Upload as a zip archive** — build the module locally, zip the output, and upload
   through the Azure Portal under *Automation Account > Modules > Add a module*.

2. **Install from a gallery** — register your private feed as described above, then use
   the Azure Portal's *Browse gallery* option or the `New-AzAutomationModule` cmdlet:

   ```powershell
   New-AzAutomationModule -AutomationAccountName 'my-automation' `
       -ResourceGroupName 'rg-automation' `
       -Name 'EnrolHQ.PowerShell' `
       -ContentLinkUri 'https://pkgs.dev.azure.com/.../enrolhq.powershell.1.0.0.nupkg'
   ```

See the [Azure Integration guide](AzureIntegration.md) for complete runbook examples.

---

## Installing the C# SDK

The C# SDK lives under `src/EnrolHQ.SDK` and can be consumed in two ways.

### Build from Source

```bash
cd src/EnrolHQ.SDK
dotnet build -c Release
```

The compiled assembly is written to `bin/Release/net8.0/`.

### Reference as a NuGet Package

If the package has been published to a NuGet feed:

```bash
dotnet add package EnrolHQ.SDK
```

Or add it to your `.csproj` manually:

```xml
<PackageReference Include="EnrolHQ.SDK" Version="1.*" />
```

See the [Publishing guide](Publishing.md) for instructions on publishing to NuGet.

---

## Verifying the Installation

After importing the module, run the following commands to confirm everything is working:

```powershell
# List all available cmdlets
Get-Command -Module EnrolHQ.PowerShell

# Check module version
Get-Module EnrolHQ.PowerShell | Select-Object Name, Version

# Test connectivity (requires valid credentials — see Authentication.md)
Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken $token
Get-EnrolHQApplications -Page 1 -PageSize 1
```

If `Get-Command` returns the list of cmdlets, the module is correctly installed.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Import-Module` fails with *module not found* | Path is wrong or the `.psd1` is missing | Verify the path points to the folder containing `EnrolHQ.PowerShell.psd1` |
| `The term 'Connect-EnrolHQ' is not recognized` | Module not imported in the current session | Run `Import-Module EnrolHQ.PowerShell` |
| `Assembly load failure` on Linux/macOS | Missing .NET runtime | Install the .NET 8 runtime: `dotnet --list-runtimes` |
| `Untrusted repository` warning during install | Repository not marked as trusted | Re-register with `-InstallationPolicy Trusted` or confirm the prompt |

---

**Next step:** [Set up authentication](Authentication.md)
