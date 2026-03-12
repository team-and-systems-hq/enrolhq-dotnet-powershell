# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/team-and-systems-hq/enrolhq-dotnet-powershell/releases/tag/v1.0.0
