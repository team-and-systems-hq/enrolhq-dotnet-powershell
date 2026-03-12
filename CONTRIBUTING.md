# Contributing

Thanks for your interest in contributing to the EnrolHQ PowerShell Toolkit.

## Development Setup

```bash
git clone https://github.com/team-and-systems-hq/enrolhq-dotnet-powershell.git
cd enrolhq-dotnet-powershell
```

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| PowerShell | 7.0+ | Module runtime and Pester tests |
| .NET SDK | 8.0+ | C# SDK build and xUnit tests |
| Pester | 5.0+ | PowerShell test framework |

### Build and Test

```powershell
# Full build + test pipeline
./build.ps1

# Or run individually
dotnet build src/EnrolHQ.SDK
dotnet test tests/EnrolHQ.SDK.Tests
Invoke-Pester tests/EnrolHQ.PowerShell.Tests

# Import for local testing
Import-Module ./src/EnrolHQ.PowerShell -Force
```

## Pull Requests

1. Fork the repo and create a feature branch from `main`
2. Make your changes
3. Add or update tests for any new functionality
4. Ensure all tests pass (`./build.ps1`)
5. Open a PR against `main`

### PR Guidelines

- Keep PRs focused on a single change
- Include a clear description of what and why
- Add tests for new cmdlets or SDK methods
- Follow existing code style and naming conventions

## Code Style

### PowerShell
- Use approved verbs (`Get-`, `Set-`, `New-`, `Remove-`, `Send-`, `Save-`, `Invoke-`)
- Add `[CmdletBinding()]` and parameter validation
- Support `-WhatIf` / `-Confirm` on write operations
- Use `Write-Verbose` for diagnostic output, not `Write-Host`

### C#
- Use `ConfigureAwait(false)` on all `await` calls in library code
- Use `init` properties for DTOs
- Use `[JsonPropertyName]` attributes for explicit JSON mapping
- Follow standard .NET naming conventions

## Reporting Issues

Use [GitHub Issues](https://github.com/team-and-systems-hq/enrolhq-dotnet-powershell/issues) with the provided templates.
