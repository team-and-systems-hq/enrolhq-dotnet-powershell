# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-09-23

Ports the leads and custom-forms resources, the application nested-data
accessors, the token-refresh timeout fix, and the integration-service and
rate-limiting guidance from the
[EnrolHQ Python SDK](https://github.com/team-and-systems-hq/enrolhq-python)
(PRs #9–#13) into both the PowerShell module and the C# SDK.

### Added

#### PowerShell Module
- `Get-EnrolHQLeads` / `Get-EnrolHQLead` / `New-EnrolHQLead` / `Set-EnrolHQLead`
  — full leads resource on the v2 API (`leads/`): list with `-IsEmailUnique` /
  `-HasStudentProfile` filters, get, create, and PUT full-replacement update.
  Set `student_profile` to a profile UUID to link a lead to an existing
  application. Replaces the legacy v1 Zapier `POST /api/v1/leads/` integration.
- `Get-EnrolHQLeadReferences` — list lead references (`lead-references/`); use a
  record's `id` as a lead's `reference`. Also available as
  `Get-EnrolHQReferenceData -Type LeadReferences`.
- `New-EnrolHQLeadReference` — create a lead reference. There is no dedicated
  write endpoint, so it round-trips the `school/` settings object (get → append
  to `lead_references` → put) and returns the new record with its
  server-assigned `id`. Throws on a duplicate slug before writing anything.
- `Get-EnrolHQForms` / `Get-EnrolHQForm` — custom form definitions
  (`forms/staff/`, `-Published` for `forms/` with audience rules), get by
  `-Slug` (`forms/{slug}/`) or find by `-Name` (title or slug).
- `Get-EnrolHQFormSubmits` — form submissions (`forms/staff-submits/`; filters
  `-Form`, `-EntryYear`, `-EntryGrade`, `-ApplicationStatus`, `-IsCompleted`).
- `Get-EnrolHQFormSubmit` — a submission with its `payload` and `form_schema`
  by `-Id`, or every submission for an `-ApplicationId` (optionally one
  `-Form`), annotated with `form_id` / `application_id` since the submits list
  omits each submit's own id.
- `Get-EnrolHQFormAnswers` — joins a submission's `payload` against its form
  schema so answers carry the question text the parent saw, instead of opaque
  keys like `group_3_social_media`. Accepts `-SubmitId`, an already-fetched
  `-Submit` (offline), `-ApplicationId [-Form]`, or `-Form` plus submit filters
  for bulk (one request per application). `-ConsentsOnly` narrows to the yes/no
  permission answers. Backed by the `ConvertTo-EnrolHQFormAnswer` private helper.
- `Set-EnrolHQFormSubmit` (overwrite a submission's `payload`),
  `Unlock-EnrolHQFormSubmit` (re-open a completed submission), and
  `Export-EnrolHQFormSubmits` (CSV, one flat row per submission, in one request).
- `Get-EnrolHQApplication -Section EmergencyContacts | MedicalData | Guardians`
  — convenience accessors for nested data that exists on the application
  *detail* serializer only. `Get-EnrolHQApplications` returns a summary
  serializer that omits these fields, which is why they appear absent from
  list-based exports.
- `-OutFile` on the core HTTP function so file-download endpoints get the same
  auth, retry and error handling as JSON ones.

#### C# SDK
- `client.Leads` — `ListPageAsync` / `ListAllAsync`, `GetAsync`, `CreateAsync`,
  `UpdateAsync` (PUT), `ReferencesAsync`, and `CreateReferenceAsync` (round-trips
  `school/`; `ArgumentException` on a duplicate slug, `EnrolHQException` if the
  reference is missing after saving). New `LeadReference` model.
- `client.Forms` — form definitions (`ListPageAsync` / `ListAllAsync`,
  `PublishedAsync`, `GetAsync(formSlug)`, `FindAsync`), submissions
  (`SubmitsPageAsync` / `SubmitsAllAsync`, `GetSubmitAsync`,
  `SubmitsForApplicationAsync`, `UpdateSubmitAsync`, `ReopenSubmitAsync`,
  `ExportSubmitsAsync`), and labelled answers (`AnswersAsync`, static
  `AnswersFrom`, `ConsentsAsync` / `ConsentsFrom`, `AnswersForApplicationAsync`,
  `IterateAnswersAsync` as `IAsyncEnumerable`). New `FormSubmit`, `FormAnswer`,
  `FormAnswerRecord` and `ConsentAnswer` models.
- `client.Applications.EmergencyContactsAsync()`, `.MedicalDataAsync()`,
  `.GuardiansAsync()` — detail-serializer accessors.
- `client.ReferenceData.LeadReferencesAsync()`.
- `client.Http` — the underlying `EnrolHQHttpClient`, as an escape hatch for
  endpoints without a dedicated resource (e.g. `integrations/sync/finished/`).

### Fixed
- C# SDK: the token-refresh `HttpClient` inside `TokenAuthHandler` now uses the
  configured client timeout (default 30 s) instead of the .NET default of 100 s;
  `EnrolHQClient(timeout: ...)` is passed through to auth requests as well
  (`TokenAuthHandler.RefreshTimeout`). The PowerShell module already applied
  `-TimeoutSec` to its refresh call.

### Examples
- `15-Leads.ps1`, `16-EmergencyContactsAndConsents.ps1`, and
  `17-CustomFormAnswers.ps1` (discovery-driven, no hardcoded ids).

### Documentation
- `docs/IntegrationService.md` — how to build the service that receives
  EnrolHQ's outbound sync signals (the **Integration Service URL** on
  *Settings > Integrations*). Covers both protocols (legacy synchronous and the
  async `sync_request` callback to `integrations/sync/finished/`), the inbound
  payload shapes, the response schemas and their validation rules, what the
  Integration Service Token and Timeout actually control, and an Azure
  Functions (PowerShell) receiver.
- README sections on emergency contacts / medical data / consents, receiving
  sync signals, and how to avoid API rate limiting; cmdlet tables for the leads
  and custom-forms cmdlets.

## [1.1.0] - 2026-06-26

Ports the read-only configuration/audit endpoints and the bulk change-status
fix from the [EnrolHQ Python SDK](https://github.com/team-and-systems-hq/enrolhq-python)
(v0.2.0) into both the PowerShell module and the C# SDK.

### Added

#### PowerShell Module
- `Get-EnrolHQAuditLog` — read the audit / change log for a student profile or
  parent (`audit/log/`). Filter with `-StudentProfileId` or `-ParentId`; uses
  cursor pagination and follows every page automatically.
- `Get-EnrolHQCmsSettings` — read the school's CMS / form configuration
  (`cms-settings/`): enquiry & event-booking copy, form labels, terms &
  conditions, parent-dashboard flags, and policy agreement items.
- `Get-EnrolHQMetafields` — read per-model field configuration (`metafields/`)
  with a `-Section` switch (`All`, `FieldSettings`, `DefaultFieldSettings`).
- `Get-EnrolHQActivityLog` — list a student profile's activity log
  (`activity-log/`), auto-paginated.
- `Get-EnrolHQReferenceData -Type ApplicationStatusSettings` — per-status labels
  and enabled / dashboard-visibility flags (`application-status-settings/`).
- Cursor-pagination support: `Get-EnrolHQAllCursorPages` private helper plus an
  `-AbsoluteEndpoint` switch on the core HTTP function to follow DRF `next` links.

#### C# SDK
- `client.AuditLog` — `ListByStudentProfileAsync` / `ListByParentAsync`, backed
  by a new `EnrolHQHttpClient.GetAllCursorPagesAsync<T>` cursor paginator.
- `client.CmsSettings.GetAsync()` and `client.Metafields` (`GetAsync`,
  `FieldSettingsAsync`, `DefaultFieldSettingsAsync`).
- `client.ReferenceData.ApplicationStatusSettingsAsync()`.

### Fixed
- Bulk **ChangeStatus** now targets records with repeated `id` query params
  (e.g. `?id=a&id=b`) instead of a comma-joined `id__in`, which the API rejects
  with "Bulk action on all items is not allowed". The PowerShell query-string
  builder now emits array values as repeated keys; `ApplicationsResource.ChangeStatusAsync`
  builds the same repeated-`id` query in the C# SDK.

### Examples
- `11-CmsSettings.ps1`, `12-Metafields.ps1`, `13-AuditLog.ps1`, and
  `14-ActivityLog.ps1`.

## [1.0.0] - 2026-03-12

### Added

#### PowerShell Module
- `Connect-EnrolHQ` / `Disconnect-EnrolHQ` — session management with automatic token refresh
- `Get-EnrolHQApplications` — list and search applications with filters (entry year, grade, status, campus)
- `Get-EnrolHQApplication` — fetch full application detail by ID
- `Get-EnrolHQApplicationCount` — count matching applications without fetching data
- `New-EnrolHQApplication` — create new applications
- `Set-EnrolHQApplication` — update applications (PUT)
- `Get-EnrolHQEvents` / `Get-EnrolHQEvent` — list and fetch staff events
- `New-EnrolHQEvent` / `Set-EnrolHQEvent` / `Remove-EnrolHQEvent` — event CRUD
- `Get-EnrolHQStaff` / `Get-EnrolHQStaffMember` — list and fetch staff
- `Get-EnrolHQDocuments` / `Send-EnrolHQDocument` / `Save-EnrolHQDocument` / `Remove-EnrolHQDocument` — document management
- `Get-EnrolHQNotes` / `New-EnrolHQNote` — notes on student profiles
- `Get-EnrolHQReferenceData` — campuses, countries, languages, attendance types
- `Get-EnrolHQAnalytics` — statistics, conversion funnels, monthly charts
- `Invoke-EnrolHQRequest` — generic authenticated API escape hatch (GET, POST, PUT, PATCH, DELETE)
- `Invoke-EnrolHQBulkOperation` — bulk email, SMS, notes, status changes
- Auto-pagination with `-All` flag across all list cmdlets
- Built-in retry with exponential backoff and jitter for 429/5xx errors
- Retry-After header support for rate limiting
- `-WhatIf` / `-Confirm` support on all write operations
- Multiple credential strategies: parameters, environment variables, SecureString
- Verbose and debug logging throughout

#### C# SDK
- `EnrolHQClient` — main client facade with resource accessors
- `TokenAuthHandler` — DelegatingHandler with automatic token refresh and concurrent 401 prevention
- `RetryHandler` — DelegatingHandler with exponential backoff for transient failures
- `EnrolHQHttpClient` — core HTTP client with GET, POST, PUT, PATCH, DELETE, pagination
- Typed models: `StudentProfile`, `ParentSummary`, `StaffMember`, `Campus`, `Note`, `ApplicationDocument`, `Event`, `Payment`
- `PaginatedResponse<T>` — generic pagination wrapper
- Typed exceptions: `ValidationException`, `AuthenticationException`, `ForbiddenException`, `NotFoundException`, `RateLimitException`
- Resource classes: Applications, Staff, Events, EventBookings, Documents, Notes, Analytics, Payments, ActivityLog, ReferenceData, EmailLog
- `ByteArrayContent`-based file uploads (retry-safe)
- `ConfigureAwait(false)` on all async paths for library safety
- Immutable DTOs with `init` properties

#### Examples
- 10 example scripts covering common workflows
- Azure Automation runbook template
- Azure Functions project template with managed identity
- Azure Data Sync examples (SQL Database + Data Lake Storage Gen2)

#### Documentation
- Installation guide with 3 install methods
- Authentication guide with security best practices
- Azure Integration guide (Automation, Functions, Key Vault)
- Publishing guide (galleries, NuGet, CI/CD)
- SDK regeneration guide

#### Testing
- 68 xUnit tests for the C# SDK
- 51 Pester tests for the PowerShell module

[1.2.0]: https://github.com/team-and-systems-hq/enrolhq-dotnet-powershell/releases/tag/v1.2.0
[1.1.0]: https://github.com/team-and-systems-hq/enrolhq-dotnet-powershell/releases/tag/v1.1.0
[1.0.0]: https://github.com/team-and-systems-hq/enrolhq-dotnet-powershell/releases/tag/v1.0.0
