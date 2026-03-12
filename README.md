# EnrolHQ PowerShell Toolkit

A production-ready PowerShell module and C# SDK for automating school enrolment workflows with the [EnrolHQ](https://www.enrolhq.com.au/) API. Built for Azure Automation, Azure Functions, and admin scripting.

> **API Reference:** [Swagger UI](https://demo.portalhq.com.au/doc/swagger/) | [ReDoc](https://demo.portalhq.com.au/doc/redoc/)

## Architecture

```
┌──────────────────────────────────────────┐
│  PowerShell Module                       │  ← Cmdlets for interactive & scripted use
│  src/EnrolHQ.PowerShell                  │    (self-contained, no build step needed)
├──────────────────────────────────────────┤
│  C# SDK (optional)                       │  ← Typed models, HTTP client, auth logic
│  src/EnrolHQ.SDK                         │    (for compiled .NET consumers)
├──────────────────────────────────────────┤
│  EnrolHQ REST API v2                     │  ← https://{instance}.enrolhq.com.au/api/v2/
└──────────────────────────────────────────┘
```

The **PowerShell module** is self-contained and requires no build step — just import and use. The **C# SDK** provides typed models and is available for compiled .NET consumers (Azure Functions C#, console apps, etc.).

## Quick Start

```powershell
# 1. Import
Import-Module ./src/EnrolHQ.PowerShell

# 2. Connect
Connect-EnrolHQ -Instance 'yourschool' -ApiToken 'your-api-token'

# 3. Use
Get-EnrolHQApplications -EntryYear 2026 -All | Export-Csv applications.csv
```

## Features

- Full coverage of core EnrolHQ API resources (applications, documents, events, staff, notes, analytics)
- Automatic token refresh — connect once, the module handles re-authentication
- Built-in retry with exponential backoff for transient errors (429, 5xx)
- Auto-pagination — use `-All` to fetch every record without manual paging
- Support for Azure Automation, Azure Functions, and scheduled jobs
- Multiple credential strategies: environment variables, SecretManagement, Azure Key Vault
- `-WhatIf` and `-Confirm` on all write operations
- Verbose/debug logging for troubleshooting
- Typed error handling with structured PowerShell ErrorRecords

## Available Cmdlets

### Connection

| Cmdlet | Description |
|--------|-------------|
| `Connect-EnrolHQ` | Authenticate and establish a session |
| `Disconnect-EnrolHQ` | Clear the current session |

### Applications

| Cmdlet | Description |
|--------|-------------|
| `Get-EnrolHQApplications` | List/search applications with filters |
| `Get-EnrolHQApplication` | Get full detail for a single application |
| `Get-EnrolHQApplicationCount` | Get count of matching applications |
| `New-EnrolHQApplication` | Create a new application |
| `Set-EnrolHQApplication` | Update an existing application (PUT) |

### Events

| Cmdlet | Description |
|--------|-------------|
| `Get-EnrolHQEvents` | List staff events |
| `Get-EnrolHQEvent` | Get a single event |
| `New-EnrolHQEvent` | Create an event |
| `Set-EnrolHQEvent` | Update an event |
| `Remove-EnrolHQEvent` | Delete an event |

### Staff

| Cmdlet | Description |
|--------|-------------|
| `Get-EnrolHQStaff` | List staff members |
| `Get-EnrolHQStaffMember` | Get a single staff member |

### Documents

| Cmdlet | Description |
|--------|-------------|
| `Get-EnrolHQDocuments` | List documents for a student profile |
| `Send-EnrolHQDocument` | Upload a document |
| `Save-EnrolHQDocument` | Download a document |
| `Remove-EnrolHQDocument` | Delete a document |

### Notes

| Cmdlet | Description |
|--------|-------------|
| `Get-EnrolHQNotes` | List notes for a student profile |
| `New-EnrolHQNote` | Add a note to a student profile |

### Reference Data & Analytics

| Cmdlet | Description |
|--------|-------------|
| `Get-EnrolHQReferenceData` | Fetch reference data (campuses, countries, languages, etc.) |
| `Get-EnrolHQAnalytics` | Fetch analytics reports (statistics, conversion, charts) |

### Advanced

| Cmdlet | Description |
|--------|-------------|
| `Invoke-EnrolHQRequest` | Generic authenticated API request (escape hatch) |
| `Invoke-EnrolHQBulkOperation` | Execute bulk operations (email, SMS, status change, etc.) |

## Documentation

| Guide | Description |
|-------|-------------|
| [Installation](docs/Installation.md) | Prerequisites, install methods, verification |
| [Authentication](docs/Authentication.md) | Credential strategies and security best practices |
| [Azure Integration](docs/AzureIntegration.md) | Azure Automation, Functions, and Key Vault |
| [Publishing](docs/Publishing.md) | Internal gallery, NuGet, CI/CD, module signing |
| [Regenerating the SDK](docs/RegeneratingSdk.md) | Updating when the API changes |

## Examples

```
examples/
├── 01-GettingStarted.ps1           # Connect, list, fetch reference data
├── 02-SearchAndFilter.ps1          # Search, filter, export to CSV
├── 03-CreateAndUpdateApplication.ps1  # Create and update applications
├── 04-DocumentManagement.ps1       # Upload, download, delete documents
├── 05-BulkOperations.ps1           # Bulk email, notes, status changes
├── 06-PaginationPatterns.ps1       # Manual vs auto-pagination
├── 07-AzureAutomation.ps1          # Azure Automation runbook template
├── 08-AzureFunction/               # Azure Functions project template
├── 09-ErrorHandling.ps1            # Error handling patterns
├── 10-ReferenceDataAndAnalytics.ps1  # Reference data and reports
└── azure-data-sync/                # Azure SQL + Data Lake sync scripts
```

## Project Structure

```
enrolhq-dotnet-powershell/
├── src/
│   ├── EnrolHQ.SDK/                # C# SDK (optional, .NET 8)
│   │   ├── Authentication/         # Token refresh handler
│   │   ├── Exceptions/             # Typed API exceptions
│   │   ├── Http/                   # HTTP client with retry
│   │   ├── Models/                 # DTOs and enums
│   │   ├── Resources/              # Resource classes per API group
│   │   └── EnrolHQClient.cs        # Main client facade
│   └── EnrolHQ.PowerShell/         # PowerShell module (self-contained)
│       ├── Classes/                # Connection state, status enums
│       ├── Private/                # HTTP client, pagination, error handling
│       └── Public/                 # Exported cmdlet functions
├── tests/
│   ├── EnrolHQ.SDK.Tests/          # xUnit tests for C# SDK
│   └── EnrolHQ.PowerShell.Tests/   # Pester tests for PowerShell module
├── examples/                       # Ready-to-use example scripts
├── docs/                           # Documentation
├── build.ps1                       # Build, test, and package script
└── LICENSE                         # MIT License
```

## Development

```powershell
git clone https://github.com/team-and-systems-hq/enrolhq-dotnet-powershell.git
cd enrolhq-dotnet-powershell

# Build & test
./build.ps1

# Or run individually
dotnet build src/EnrolHQ.SDK
dotnet test tests/EnrolHQ.SDK.Tests
Invoke-Pester tests/EnrolHQ.PowerShell.Tests

# Import for local testing
Import-Module ./src/EnrolHQ.PowerShell -Force
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, coding standards, and pull request guidelines.

## License

[MIT](LICENSE)
