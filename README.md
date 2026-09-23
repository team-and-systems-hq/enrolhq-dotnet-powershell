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
│  EnrolHQ REST API v2                     │  ← https://{your-enrolhq-domain}/api/v2/
└──────────────────────────────────────────┘
```

The **PowerShell module** is self-contained and requires no build step — just import and use. The **C# SDK** provides typed models and is available for compiled .NET consumers (Azure Functions C#, console apps, etc.).

## Quick Start

```powershell
# 1. Import
Import-Module ./src/EnrolHQ.PowerShell

# 2. Connect (your EnrolHQ domain)
Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'your-api-token'

# 3. Use
Get-EnrolHQApplications -EntryYear 2026 -All | Export-Csv applications.csv
```

## Features

- Full coverage of core EnrolHQ API resources (applications, leads, custom forms, documents, events, staff, notes, analytics)
- Automatic token refresh — connect once, the module handles re-authentication
- Built-in retry with exponential backoff for transient errors (429, 5xx)
- Auto-pagination — use `-All` to fetch every record without manual paging (page-number and cursor pagination both handled automatically)
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
| `Get-EnrolHQApplication` | Get full detail for a single application (`-Section EmergencyContacts` / `MedicalData` / `Guardians` for the detail-only nested data) |
| `Get-EnrolHQApplicationCount` | Get count of matching applications |
| `New-EnrolHQApplication` | Create a new application |
| `Set-EnrolHQApplication` | Update an existing application (PUT) |

### Leads

| Cmdlet | Description |
|--------|-------------|
| `Get-EnrolHQLeads` | List leads (pre-enquiry contacts) with `-IsEmailUnique` / `-HasStudentProfile` filters |
| `Get-EnrolHQLead` | Get a single lead |
| `New-EnrolHQLead` | Create a lead (replaces the legacy v1 Zapier `POST /api/v1/leads/`) |
| `Set-EnrolHQLead` | Update a lead (PUT) |
| `Get-EnrolHQLeadReferences` | List lead references (which form/source a lead came from) |
| `New-EnrolHQLeadReference` | Create a lead reference (round-trips the `school/` settings object) |

### Custom Forms

| Cmdlet | Description |
|--------|-------------|
| `Get-EnrolHQForms` | List form definitions (`-Published` for the parent-facing view with audience rules) |
| `Get-EnrolHQForm` | Get a published form by `-Slug`, or find one by `-Name` (title or slug) |
| `Get-EnrolHQFormSubmits` | List form submissions (filters: `-Form`, `-EntryYear`, `-EntryGrade`, `-ApplicationStatus`, `-IsCompleted`) |
| `Get-EnrolHQFormSubmit` | Get a submission with its `payload` by `-Id`, or every submission for an `-ApplicationId` |
| `Get-EnrolHQFormAnswers` | Flatten a submission's answers with the question text the parent saw (`-ConsentsOnly` for yes/no permissions) |
| `Set-EnrolHQFormSubmit` | Overwrite a submission's `payload` (staff edit) |
| `Unlock-EnrolHQFormSubmit` | Re-open a completed submission so the parent can edit it again |
| `Export-EnrolHQFormSubmits` | Download the form-submits report as CSV (one flat row per submission) |

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

### Configuration & Logs

| Cmdlet | Description |
|--------|-------------|
| `Get-EnrolHQActivityLog` | List a student profile's activity log (emails, status changes, notes) |
| `Get-EnrolHQAuditLog` | List the audit/change log for a student profile or parent (cursor-paginated) |
| `Get-EnrolHQCmsSettings` | Read the school's CMS / form configuration settings |
| `Get-EnrolHQMetafields` | Read per-model field configuration (labels, enabled/mandatory by scope) |

### Reference Data & Analytics

| Cmdlet | Description |
|--------|-------------|
| `Get-EnrolHQReferenceData` | Fetch reference data (campuses, countries, languages, lead references, application status settings, etc.) |
| `Get-EnrolHQAnalytics` | Fetch analytics reports (statistics, conversion, charts) |

### Advanced

| Cmdlet | Description |
|--------|-------------|
| `Invoke-EnrolHQRequest` | Generic authenticated API request (escape hatch) |
| `Invoke-EnrolHQBulkOperation` | Execute bulk operations (email, SMS, status change, etc.) |

## Emergency contacts, medical data and consents

Two things are commonly reported as "missing from the API". Neither is:

**Emergency contacts, medical data and guardians** are on the application
*detail* serializer only. `Get-EnrolHQApplications` returns a lighter summary
serializer that omits them, so iterating the list endpoint never surfaces
them:

```powershell
# Not there — the list returns the summary serializer
$page = Get-EnrolHQApplications -PageSize 1
$page.Results[0].PSObject.Properties['emergency_contacts']   # $null

# There — detail serializer
Get-EnrolHQApplication -Id $applicationId -Section EmergencyContacts
Get-EnrolHQApplication -Id $applicationId -Section MedicalData
Get-EnrolHQApplication -Id $applicationId -Section Guardians
```

**Photo/video consents** are not application fields at all — they are answers
on a custom form, stored in that submission's `payload`:

```powershell
$form = Get-EnrolHQForm -Name 'photo-permission'          # by title or slug
foreach ($submit in Get-EnrolHQFormSubmit -ApplicationId $applicationId -Form $form.id) {
    foreach ($answer in Get-EnrolHQFormAnswers -SubmitId $submit.id -ConsentsOnly) {
        "$($answer.label): $($answer.value)"
    }
}
```

For a bulk load, the CSV export flattens student details, emergency contacts
and every consent answer into one row per submission — in a single request:

```powershell
Export-EnrolHQFormSubmits -DestinationPath consents.csv -Form $form.id -IsCompleted $true
```

If you want structured objects instead, use `Get-EnrolHQFormAnswers -Form`.
Note that the `Get-EnrolHQFormSubmits` summary records carry `student_profile`
but **not** the submit's own id, so they can't be passed to
`Get-EnrolHQFormSubmit -Id`; `-Form` resolves that for you at the cost of one
request per application, and tags every answer with `student_profile`,
`submit_id`, `form_id` and `completed_at`:

```powershell
Get-EnrolHQFormAnswers -Form $form.id -IsCompleted $true -ConsentsOnly |
    Group-Object submit_id |
    ForEach-Object { "$($_.Group[0].student_profile.last_name): $(($_.Group | ForEach-Object { "$($_.label)=$($_.value)" }) -join ', ')" }
```

The same surface exists in the C# SDK:

```csharp
var contacts = await client.Applications.EmergencyContactsAsync(applicationId);
var medical  = await client.Applications.MedicalDataAsync(applicationId);

var form   = await client.Forms.FindAsync("photo-permission");
var formId = form?.GetProperty("id").GetString();
foreach (var submit in await client.Forms.SubmitsForApplicationAsync(applicationId, form: formId))
    foreach (var (name, consent) in await client.Forms.ConsentsAsync(submit.Id))
        Console.WriteLine($"{consent.Label}: {consent.Value}");

await client.Forms.ExportSubmitsAsync("consents.csv", new() { ["form"] = formId, ["is_completed"] = "true" });
await foreach (var record in client.Forms.IterateAnswersAsync(form: formId, new() { ["is_completed"] = "true" }))
    Console.WriteLine($"{record.StudentProfile?.GetProperty("last_name")}: {record.Answers.Count} answers");
```

See [`examples/16-EmergencyContactsAndConsents.ps1`](examples/16-EmergencyContactsAndConsents.ps1)
and [`examples/17-CustomFormAnswers.ps1`](examples/17-CustomFormAnswers.ps1).

## Receiving sync signals (integration service)

EnrolHQ can push sync signals *out* to a service you host — the URL configured
under **Settings > Integrations > Integration Service Edit**. It `POST`s JSON
carrying student profile ids, authenticated with the shared bearer token from
that screen; you read the profiles with this module (or the C# SDK), write them
into the school's SIS, and report the outcome back.

There are two protocols (which one fires depends on the school's `NEW_SYNC`
feature flag, so handle both): a legacy synchronous one where you return the
result in the HTTP response body within the configured timeout, and an async one
that hands you a `sync_request` id to acknowledge immediately and answer later
via `POST {school_domain}/api/v2/integrations/sync/finished/`.

There is no dedicated cmdlet for the callback yet — use the escape hatches:
`Invoke-EnrolHQRequest -Method POST -Endpoint 'integrations/sync/finished/' -Body $payload`
in PowerShell, or `client.Http.PostAsync("integrations/sync/finished/", payload)`
in C#.

See [docs/IntegrationService.md](docs/IntegrationService.md) for the payload
shapes, response schemas, what the token and timeout actually control, and a
working Azure Functions receiver.

## Rate limiting

EnrolHQ instances sit behind a reverse proxy that returns **HTTP 429** when you
send requests too quickly. Bulk jobs (fetching detail for thousands of
applications, backfills, reconciliation scripts) will hit this unless you pace
them.

### Connect once, reuse the session

The single biggest cause of unexpected 429s is **connecting per job, per
runspace or per request**. Every `Connect-EnrolHQ` (and every new
`EnrolHQClient` in C#) calls `accounts/refresh/` to exchange your long-lived
API token for a short-lived access token, so each new connection is an extra
hit on the auth endpoint — and that endpoint rate-limits harder than the rest
of the API.

```powershell
# BAD: a connection per item means a token refresh per item
foreach ($id in $ids) {
    Connect-EnrolHQ -Instance $instance -ApiToken $token   # authenticates every loop
    Get-EnrolHQApplication -Id $id
}

# GOOD: connect once, reuse the module-scoped session
Connect-EnrolHQ -Instance $instance -ApiToken $token
foreach ($id in $ids) {
    Get-EnrolHQApplication -Id $id
}
```

The session holds one access token, refreshed automatically only when it
expires. In C#, build one `EnrolHQClient` and share it — it owns one
`HttpClient` (connection pooling) and one access token.

### Go sequential, with a small delay

Concurrency is where bulk jobs fall over. Six parallel runspaces against a
production instance is enough to trigger 429s within seconds. Sequential
requests with a short sleep are slower per request but finish sooner overall,
because you never spend time backing off:

```powershell
foreach ($id in $ids) {
    $detail = Get-EnrolHQApplication -Id $id
    ...
    Start-Sleep -Milliseconds 150   # ~6 req/s, sustained without 429s
}
```

If you do need concurrency (`ForEach-Object -Parallel`), keep it to 2–3
workers and remember each runspace has its own module scope — connect inside
the worker, once, not per item.

### Back off and retry

The module already retries 429 and 5xx responses with exponential backoff and
honours the `Retry-After` header; tune it with `Connect-EnrolHQ -MaxRetries`
(default 3). The C# `RetryHandler` does the same, and `RateLimitException`
exposes `RetryAfterSeconds` when the server sends one. If you wrap your own
retry around a whole job, back off exponentially rather than tight-looping:

```powershell
function Invoke-WithBackoff {
    param([scriptblock]$Action, [int]$Attempts = 6)
    for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
        try { return & $Action }
        catch {
            if ($_.FullyQualifiedErrorId -notlike 'EnrolHQ.RateLimitError*') { throw }
            Start-Sleep -Seconds (5 * [math]::Pow(2, $attempt))
        }
    }
    throw 'Still rate limited after retries'
}

# Module API errors are non-terminating by default, so pass -ErrorAction Stop
# (or set $ErrorActionPreference = 'Stop') for try/catch to see them.
$detail = Invoke-WithBackoff { Get-EnrolHQApplication -Id $id -ErrorAction Stop }
```

> **Gotcha:** a 429 on the *token refresh* endpoint does not surface as a
> rate-limit error. `Connect-EnrolHQ` fails with
> `Failed to connect to EnrolHQ: Token refresh failed: ... 429 ...`. When the
> module refreshes automatically mid-job (after a 401), a throttled refresh
> currently surfaces on that request as `EnrolHQ.AuthenticationError`
> ("Authentication failed ... Check your API token"), not as
> `EnrolHQ.RateLimitError`; in C# it is an `AuthenticationException` whose
> message contains the 429 body. If you know your token is valid, treat both
> as rate limiting:
>
> ```powershell
> try {
>     $detail = Get-EnrolHQApplication -Id $id -ErrorAction Stop
> }
> catch {
>     if ($_.Exception.Message -match '429|Too Many' -or
>         $_.FullyQualifiedErrorId -like 'EnrolHQ.AuthenticationError*') {
>         ...  # treat as rate limiting, back off and retry
>     }
>     else { throw }
> }
> ```

### Make bulk jobs resumable

Cache results to disk as you go and skip what you already have. A job that dies
2,000 records in should resume, not restart:

```powershell
$cachePath = './cache.json'
$cache = if (Test-Path $cachePath) {
    $obj = Get-Content $cachePath -Raw | ConvertFrom-Json -AsHashtable
    if ($obj) { $obj } else { @{} }
} else { @{} }

$todo = $ids | Where-Object { -not $cache.ContainsKey($_) }
$n = 0
foreach ($id in $todo) {
    $cache[$id] = Get-EnrolHQApplication -Id $id
    Start-Sleep -Milliseconds 150
    if ((++$n) % 100 -eq 0) {                       # checkpoint periodically
        $cache | ConvertTo-Json -Depth 20 | Set-Content $cachePath
    }
}
$cache | ConvertTo-Json -Depth 20 | Set-Content $cachePath
```

### Fetch less

Prefer one paginated sweep over many single-record lookups — `-All` with a
large `-PageSize` returns 100–200 records per request instead of one:

```powershell
# One sweep, ~40 requests for 4,000 records
$byExternalId = @{}
foreach ($app in Get-EnrolHQApplications -All -PageSize 200) {
    if ($app.external_id) { $byExternalId[$app.external_id] = $app }
}
```

Note that some documented filters are **ignored server-side** — passing
`-ExternalId` to `Get-EnrolHQApplications` returns the full unfiltered result
set, not a single match. Always verify a filter narrowed the results (check
the page's `.Count`) before relying on it; otherwise build a local index as
above.

Detail (`Get-EnrolHQApplication`) returns fields the list serializer omits —
`payments`, addresses, medical data, emergency contacts. Only drop to
per-record fetches for the fields you genuinely need.

## Documentation

| Guide | Description |
|-------|-------------|
| [Installation](docs/Installation.md) | Prerequisites, install methods, verification |
| [Authentication](docs/Authentication.md) | Credential strategies and security best practices |
| [Azure Integration](docs/AzureIntegration.md) | Azure Automation, Functions, and Key Vault |
| [Integration Service](docs/IntegrationService.md) | Receiving EnrolHQ's outbound sync signals (both protocols, response schemas, Azure Functions receiver) |
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
├── 11-CmsSettings.ps1              # Read CMS / form configuration
├── 12-Metafields.ps1              # Inspect per-model field configuration
├── 13-AuditLog.ps1                 # Audit/change log (cursor pagination)
├── 14-ActivityLog.ps1              # Student profile activity log
├── 15-Leads.ps1                    # Leads and lead references
├── 16-EmergencyContactsAndConsents.ps1  # Detail-only nested data + custom form consents
├── 17-CustomFormAnswers.ps1        # Discovery-driven custom form answers (no hardcoded ids)
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
