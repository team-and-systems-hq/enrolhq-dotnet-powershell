# Building an EnrolHQ Integration Service

This document describes the server you build to receive sync signals from
EnrolHQ — the thing that sits behind **Integration Service URL** on
*Settings > Integrations > Integration Service Edit*.

EnrolHQ calls this an "integration service". It is the bridge between EnrolHQ
and a school's SIS (Synergetic, TASS, Sentral, PCSchool, Edumate, Compass,
Veracross, …). EnrolHQ pushes a signal to your URL; you read the student
profiles out of the EnrolHQ API (that's what this module and the C# SDK are
for), write them into the SIS, and report the outcome back.

> There is no dedicated cmdlet or SDK resource for the callback yet. This
> document covers the protocol; the examples use the module's escape hatch
> (`Invoke-EnrolHQRequest`) and the C# SDK's `client.Http` for the callback,
> and an Azure Functions (PowerShell) app as the receiver.

---

## 1. The settings screen, field by field

| Field | Model field | What it does |
|-------|-------------|--------------|
| **Integration Service** | `name` | Which SIS this row is for. One row per school per SIS (`unique_together = (school, name)`). The value is echoed back to you in every payload as `integration`. |
| **Active** | `is_active` | Off means EnrolHQ will not call you at all — the sync endpoints 404 on `integration_services.active()`. |
| **Bulk Sync Enabled** | `is_bulk_sync_enabled` | Allows the staff "bulk sync" action over a filtered set of profiles. Off means only one-profile-at-a-time syncs. |
| **Integration Service URL** | `url` | Your HTTPS endpoint. EnrolHQ `POST`s JSON here. This is the *only* outbound destination — there are no other webhooks. |
| **Integration Service Token** | `token` | A shared secret **you** choose and paste in. EnrolHQ sends it as `Authorization: Bearer <token>`. Write-only in the API (`SecretKeyField`), so it is masked after saving — record it somewhere when you set it. Max 255 chars. |
| **Integration Service Timeout** | `timeout` | Seconds EnrolHQ waits for your HTTP response. Default `10`. Passed straight to the outbound HTTP call as its timeout. |
| **Scheduled Sync Features** | `scheduled_sync_features` | Gates which sync actions staff see. **"Synchronous sync (default)" must be ticked** — that is the toggle for the sync that calls your URL. With nothing ticked, the sync menu does not render at all and your service is never called. |
| **Additional Sync Instruction** | `sync_instruction` | A private document staff can download from the app. Not sent to you. |

### What the token and timeout actually do

**Token.** There is no HMAC, no signature, no replay protection, no IP
allowlist. Authentication is a static bearer token, chosen by you, compared by
you. So:

- Generate something long and random, e.g.
  `[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48))`.
- Compare it in constant time
  (`[System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals`),
  not with `-eq`.
- Terminate TLS. The token is sent in the clear inside the header.
- Reject anything without a valid token *before* doing any work, and return
  `401`/`403`.

**Timeout.** It bounds EnrolHQ's patience, and it means different things in the
two protocols below:

- **Legacy synchronous protocol** — a staff member is sitting in front of a
  spinner while your service does the entire SIS write. The timeout must cover
  the full round trip. Blow it and the sync is recorded as a failure even if
  the SIS write actually succeeded.
- **Async (`sync_request`) protocol** — the timeout only covers your
  acknowledgement. Return `200` immediately, do the work on a worker, and post
  the result back later. A small timeout (10–30s) is correct here.

Set it in seconds. It is a `PositiveSmallIntegerField` (0–32767) and the API
marks it required, but there is no minimum validator — **do not set `0`**,
because EnrolHQ's HTTP client treats a zero timeout as "give up immediately"
and every sync will fail.

---

## 2. Two protocols

Which payload you receive depends on the `NEW_SYNC` feature flag on the school.
You do not get to choose, and you cannot read the flag over the API — so
**handle both**. They are trivially distinguishable: the async payload has a
`sync_request` key and the legacy one does not.

```
Legacy (synchronous)                  Async (NEW_SYNC)
--------------------                  -----------------
EHQ ──POST──▶ you                     EHQ ──POST──▶ you
              │ writes to SIS                       │
EHQ ◀─result──┘ (within timeout)      EHQ ◀──200────┘ (ack only, empty body)
                                                    │ writes to SIS on a worker
                                      EHQ ◀─POST────┘ /integrations/sync/finished/
```

---

## 3. The inbound request

Always `POST`, from EnrolHQ to your `url`:

```http
POST /your/endpoint HTTP/1.1
Content-type: application/json
Authorization: Bearer <Integration Service Token>

{ ...payload... }
```

`school_domain` is present in every payload and is the school's own EnrolHQ
origin (`https://yourschool.enrolhq.com.au`, no trailing slash). EnrolHQ
resolves the school from the `Host` header on incoming API requests, so
**always** use the `school_domain` from the payload when you call back or read
data — never a hardcoded host. That is what makes one integration service
deployment usable by many schools.

`integration` is the `IntegrationServiceEnum` value for the row that called
you: `SYNERGETIC`, `SENTRAL`, `ENGAGE`, `SCHOOLEDGE`, `SCHOOLPRO`, `PCSCHOOL`,
`TASS`, `EDUMATE`, `KAMAR`, `ZUNIA`, `WONDE`, `COMPASS`, `SYNERGETIC_REST`,
`VERACROSS`, `SHAREPOINT`.

### 3a. Async payload (`NEW_SYNC` schools)

Sent for both single-profile and bulk syncs — the only difference is the length
of `profiles`.

```json
{
  "sync_request": "1b5f6b2e-1f6a-4a6d-9d1e-5d5b2a4c7e01",
  "school_domain": "https://yourschool.enrolhq.com.au",
  "integration": "SYNERGETIC",
  "profiles": [
    "9a7a0b3e-3d2c-4f51-a0e6-2c1b8d9f4a10",
    "0c2e7d41-5b6a-4c3f-8e9d-1a2b3c4d5e6f"
  ]
}
```

`sync_request` is the correlation id. Keep it — you need it to report back, and
EnrolHQ accepts exactly one response per `sync_request`.

### 3b. Legacy payload — single profile

```json
{
  "school_domain": "https://yourschool.enrolhq.com.au",
  "integration": "SENTRAL",
  "profile_id": "9a7a0b3e-3d2c-4f51-a0e6-2c1b8d9f4a10"
}
```

### 3c. Legacy payload — bulk sync

Capped at 100 profiles per call by EnrolHQ.

```json
{
  "school_domain": "https://yourschool.enrolhq.com.au",
  "integration": "SENTRAL",
  "profiles": ["<uuid>", "<uuid>", "..."]
}
```

### Reading the profile data

The payload carries **ids only**. Fetch the detail with the module, against
the `school_domain` you were given:

```powershell
Connect-EnrolHQ -BaseUrl "$schoolDomain/api/v2/" -ApiToken $env:ENROLHQ_API_TOKEN

$application = Get-EnrolHQApplication -Id $profileId
$contacts    = Get-EnrolHQApplication -Id $profileId -Section EmergencyContacts
$medical     = Get-EnrolHQApplication -Id $profileId -Section MedicalData
$documents   = Get-EnrolHQDocuments -StudentProfileId $profileId
```

Or with the C# SDK:

```csharp
using var client = EnrolHQClient.FromBaseUrl($"{schoolDomain}/api/v2/", apiToken);

var application = await client.Applications.GetAsync(profileId);
var contacts    = await client.Applications.EmergencyContactsAsync(profileId);
var medical     = await client.Applications.MedicalDataAsync(profileId);
var documents   = await client.Documents.ListAllAsync(profileId);
```

Remember that emergency contacts, medical data and guardians are on the
*detail* serializer only, and that consents live on custom form submissions —
see the README section "Emergency contacts, medical data and consents".

---

## 4. Responding — async protocol

Two steps.

**Step 1: acknowledge.** Return any `2xx` with an empty body, within the
timeout. EnrolHQ only checks that the response is OK. If you return non-2xx or
time out, EnrolHQ raises a `ServiceError` to the staff user **and rolls the
whole `SyncRequest` back** (the send is wrapped in a database transaction) —
so there is no `sync_request` row left to respond to. Never do SIS work before
acknowledging.

**Step 2: post the result** to the school's API when the work finishes:

```
POST {school_domain}/api/v2/integrations/sync/finished/
```

Authenticated as a **staff** user — the endpoint requires `IsSchoolStaff`, so a
normal EnrolHQ API token (Profile icon > API Token) belonging to a staff
account is what you want. Body:

```json
{
  "sync_request": "1b5f6b2e-1f6a-4a6d-9d1e-5d5b2a4c7e01",
  "student_profiles": [
    {
      "student_profile": "9a7a0b3e-3d2c-4f51-a0e6-2c1b8d9f4a10",
      "is_success": true,
      "error": "",
      "warning": "Address truncated to 60 chars",
      "external_id": "SIS-10023",
      "user_parent_external_id": "SIS-P-55011",
      "non_user_parent_external_id": "SIS-P-55012"
    },
    {
      "student_profile": "0c2e7d41-5b6a-4c3f-8e9d-1a2b3c4d5e6f",
      "is_success": false,
      "error": "Duplicate student record in Synergetic"
    }
  ],
  "export_file": "data:text/xml;filename:export.xml;base64,PGRhdGE+PC9kYXRhPg=="
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `sync_request` | yes | Must be a known, **unanswered** request. A second response returns `400` — `"The response to the '<id>' request has already been received."` |
| `student_profiles` | yes, non-empty | The set of `student_profile` ids must **exactly match** the ids in the request — no extras, no omissions — or `400` `"The student profiles in the response do not match the profiles in the request."` |
| `student_profiles[].is_success` | yes | Boolean, per profile. |
| `student_profiles[].error` / `.warning` | no | Strings, max 1024 chars each. Default `""`. |
| `student_profiles[].external_id` | no | The SIS id for the student. **Written back onto the student profile** when non-empty. |
| `student_profiles[].user_parent_external_id` | no | SIS id for the parent who has the EnrolHQ login. Written back. |
| `student_profiles[].non_user_parent_external_id` | no | SIS id for the second parent. Written back only if that parent exists. |
| `export_file` | no | A data URI, `xml` or `csv` only: `data:<mime>;filename:<name>.<ext>;base64,<data>`. The `filename:` segment is mandatory — without it the upload is rejected. Virus-scanned and extension-checked on arrival. |

On success EnrolHQ stores the response, writes the external ids, and notifies:

- single-profile sync → an in-app notification to the staff member
  (*"Synchronization to Synergetic for 'Jane Doe' is complete…"*);
- bulk sync → an email report to the staff member who started it, with
  `export_file` attached if you sent one.

It returns `200` with an empty body. A `400` means your payload was rejected
and **nothing was stored** — the `sync_request` is still unanswered, so a
corrected retry will be accepted.

### Sending the callback

The module handles the token refresh dance (long-lived API token → short-lived
access token, with automatic retry on `401`). There's no dedicated cmdlet for
this endpoint yet, so use the generic request escape hatch:

```powershell
Connect-EnrolHQ -BaseUrl "$schoolDomain/api/v2/" -ApiToken $env:ENROLHQ_API_TOKEN

Invoke-EnrolHQRequest -Method POST -Endpoint 'integrations/sync/finished/' -Body $payload
```

C# SDK equivalent, via the underlying HTTP client:

```csharp
using var client = EnrolHQClient.FromBaseUrl($"{schoolDomain}/api/v2/", apiToken);

await client.Http.PostAsync("integrations/sync/finished/", payload);
```

Raw equivalent, if you'd rather not depend on the module at all:

```powershell
$access = (Invoke-RestMethod -Method Post -Uri "$schoolDomain/api/v2/accounts/refresh/" `
    -Headers @{ Authorization = "Token $apiToken" } -TimeoutSec 30).access_token

Invoke-RestMethod -Method Post -Uri "$schoolDomain/api/v2/integrations/sync/finished/" `
    -Headers @{ Authorization = "Token $access" } `
    -ContentType 'application/json' `
    -Body ($payload | ConvertTo-Json -Depth 10) `
    -TimeoutSec 30
```

Access tokens are short-lived — refresh on `401` and retry once.

---

## 5. Responding — legacy synchronous protocol

You return the result **in the HTTP response body**, as JSON, inside the
timeout.

The single most important rule: **always return `2xx` with a JSON body, even
when the sync failed.** EnrolHQ only reads the response body when the status
is OK; on any other status it substitutes the reason phrase (e.g.
`"Bad Gateway"`), which is not JSON, and the sync is logged as a bare failure
with no detail. Report failures in the `errors` array of a `200` response, not
with a `500`.

### Single-profile response

```json
{
  "profile_id": "9a7a0b3e-3d2c-4f51-a0e6-2c1b8d9f4a10",
  "external_id": "SIS-10023",
  "user_parent": { "external_id": "SIS-P-55011" },
  "non_user_parent": { "external_id": "SIS-P-55012" },
  "errors": [],
  "warnings": ["Address truncated to 60 chars"],
  "message": "Application sync successful",
  "file_name": "export.xml",
  "file": "PGRhdGE+PC9kYXRhPg=="
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `profile_id` | yes | UUID, echoed from the request. |
| `external_id` | no | SIS id; written onto the student profile. |
| `user_parent` / `non_user_parent` | no | **Objects**, not strings: `{"external_id": "..."}`. `null` or `{}` is read as `""`. |
| `errors` | no | List of strings. A non-empty list marks the call-log entry `is_success=false`. |
| `warnings` | no | List of strings; shown to staff, not treated as failure. |
| `message` | no | Summary line shown in the UI and the call log (truncated to 1024 chars in the log). |
| `file_name` + `file` | no | Both or neither. `file` is base64 (no data-URI prefix here, unlike the async `export_file`); the browser offers it as a download. The base64 blob is stripped before the response is written to the call log. |

### Bulk response

```json
{
  "profiles": ["<uuid>", "<uuid>"],
  "errors": [],
  "message": "Sync complete",
  "file_name": "syn-bulk.xml",
  "file": "PGRhdGE+PC9kYXRhPg=="
}
```

`profiles` is **required** and each id must be a student profile that exists in
that school — unknown ids are a validation error.

### Failure semantics

- Body that is not valid JSON, an empty body, a non-2xx status, a connection
  error, or a timeout → the raw text is written to the call log and the staff
  user sees `"Error: Profile did not sync."`
- Valid JSON with a non-empty `errors` → logged as a failure, with your
  messages shown.
- Valid JSON with empty/absent `errors` → logged as a success.

---

## 6. Logs

- **Call Log** — the legacy per-profile responses
  (`GET integrations/services/responses/?integration_service=<uuid>`): timestamp,
  student, raw response, message, success flag.
- **Sync request log** (async protocol) —
  `GET integrations/sync/` and `GET integrations/sync/for-profile/<uuid>/`,
  showing each request, its profiles, per-profile errors/warnings and the
  exported file.

Both are reachable with `Invoke-EnrolHQRequest -Method GET -Endpoint ...`.

Malformed async callbacks are logged server-side as
`"Wrong sync response from integration service: sync_request=… ,errors=…"`,
which is what to ask EnrolHQ support for when a callback is being rejected.

---

## 7. A minimal receiver (Azure Functions, PowerShell)

Handles both protocols, acknowledges first, and does the async work on a
queue-triggered worker. Two functions in one Function App:

```
/EhqSync/            HTTP trigger  — validates the token, branches on protocol
  function.json
  run.ps1
/EhqSyncWorker/      Queue trigger — does the SIS work, posts the callback
  function.json
  run.ps1
profile.ps1          Import-Module EnrolHQ.PowerShell, plus the shared
                     Sync-ProfileToSis / Build-ExportXml functions so both
                     functions can call them (see examples/08-AzureFunction)
requirements.psd1    @{ 'EnrolHQ.PowerShell' = '1.*' }
```

App settings:

| Setting | Purpose |
|---------|---------|
| `EHQ_INTEGRATION_TOKEN` | Matches **Integration Service Token** on the settings screen. Store it in Key Vault and reference it. |
| `ENROLHQ_API_TOKEN` | A *staff* API token, used to read profiles and post callbacks. |
| `SYNC_QUEUE_CONNECTION` | Storage connection string for the work queue. |

Point **Integration Service URL** at
`https://<app>.azurewebsites.net/api/ehq/sync?code=<function key>` (the
function key is a second, transport-level secret; the bearer token check
below still runs).

### `EhqSync/function.json`

```json
{
  "bindings": [
    {
      "authLevel": "function",
      "type": "httpTrigger",
      "direction": "in",
      "name": "Request",
      "methods": ["post"],
      "route": "ehq/sync"
    },
    { "type": "http", "direction": "out", "name": "Response" },
    {
      "type": "queue",
      "direction": "out",
      "name": "SyncQueue",
      "queueName": "ehq-sync-requests",
      "connection": "SYNC_QUEUE_CONNECTION"
    }
  ]
}
```

### `EhqSync/run.ps1`

```powershell
using namespace System.Net

param($Request, $TriggerMetadata)

$ErrorActionPreference = 'Stop'

function Test-Authorized {
    param($Request)
    $header = [string]$Request.Headers['Authorization']
    if (-not $header.StartsWith('Bearer ', [StringComparison]::Ordinal)) { return $false }
    $presented = [System.Text.Encoding]::UTF8.GetBytes($header.Substring(7))
    $expected  = [System.Text.Encoding]::UTF8.GetBytes([string]$env:EHQ_INTEGRATION_TOKEN)
    # Constant-time compare — never `-eq` on secrets.
    return [System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals($presented, $expected)
}

function Sync-ProfileToSis {
    <#
        Returns @{ IsSuccess; Error; Warning; ExternalId; UserParentExternalId; NonUserParentExternalId }.
        Replace the body with the real SIS write. Shown inline here for
        readability; in a real app define it in profile.ps1 so EhqSyncWorker
        can call it too.
    #>
    param([string]$ProfileId)
    $application = Get-EnrolHQApplication -Id $ProfileId
    $contacts    = Get-EnrolHQApplication -Id $ProfileId -Section EmergencyContacts
    # ... write $application / $contacts to the SIS ...
    return @{
        IsSuccess               = $true
        Error                   = ''
        Warning                 = ''
        ExternalId              = 'SIS-10023'
        UserParentExternalId    = 'SIS-P-55011'
        NonUserParentExternalId = ''
    }
}

function Send-Json {
    param([int]$StatusCode = 200, $Body = $null)
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode  = $StatusCode
        ContentType = 'application/json'
        Body        = if ($null -ne $Body) { $Body | ConvertTo-Json -Depth 10 } else { '' }
    })
}

# --- 1. Reject anything without a valid token before doing any work ----------
if (-not (Test-Authorized $Request)) {
    Send-Json -StatusCode 401 -Body @{ detail = 'invalid token' }
    return
}

$payload      = $Request.Body
$schoolDomain = $payload.school_domain

# --- 2. Async protocol: acknowledge now, report later ------------------------
if ($payload.sync_request) {
    # Hand the whole payload to the queue worker. Return 2xx with an EMPTY
    # body inside the timeout — otherwise EnrolHQ rolls the SyncRequest back.
    Push-OutputBinding -Name SyncQueue -Value ($payload | ConvertTo-Json -Depth 10 -Compress)
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ StatusCode = 200; Body = '' })
    return
}

# --- 3. Legacy protocol: do the work inside the timeout ----------------------
# ALWAYS answer 200 with a JSON body — failures go in `errors`, never a 500.
Connect-EnrolHQ -BaseUrl "$schoolDomain/api/v2/" -ApiToken $env:ENROLHQ_API_TOKEN

if ($payload.profile_id) {                                   # single profile
    $profileId = $payload.profile_id
    try   { $r = Sync-ProfileToSis -ProfileId $profileId }
    catch { $r = @{ IsSuccess = $false; Error = "$($_.Exception.Message)"; Warning = '' } }

    Send-Json -Body @{
        profile_id      = $profileId
        external_id     = [string]$r.ExternalId
        user_parent     = @{ external_id = [string]$r.UserParentExternalId }
        non_user_parent = @{ external_id = [string]$r.NonUserParentExternalId }
        errors          = @(if (-not $r.IsSuccess) { $r.Error })
        warnings        = @(if ($r.Warning) { $r.Warning })
        message         = if ($r.IsSuccess) { 'Sync complete' } else { 'Sync failed' }
    }
    return
}

$errors = [System.Collections.Generic.List[string]]::new()   # bulk
foreach ($profileId in $payload.profiles) {
    try {
        $r = Sync-ProfileToSis -ProfileId $profileId
        if (-not $r.IsSuccess) { $errors.Add("${profileId}: $($r.Error)") }
    }
    catch { $errors.Add("${profileId}: $($_.Exception.Message)") }
}
Send-Json -Body @{
    profiles = @($payload.profiles)
    errors   = @($errors)
    message  = if ($errors.Count -eq 0) { 'Bulk sync complete' } else { 'Bulk sync finished with errors' }
}
```

### `EhqSyncWorker/function.json`

```json
{
  "bindings": [
    {
      "type": "queueTrigger",
      "direction": "in",
      "name": "QueueItem",
      "queueName": "ehq-sync-requests",
      "connection": "SYNC_QUEUE_CONNECTION"
    }
  ]
}
```

### `EhqSyncWorker/run.ps1`

```powershell
param($QueueItem, $TriggerMetadata)

$ErrorActionPreference = 'Stop'

$payload      = $QueueItem | ConvertFrom-Json
$schoolDomain = $payload.school_domain

# Always the school_domain from the payload — never a hardcoded host.
Connect-EnrolHQ -BaseUrl "$schoolDomain/api/v2/" -ApiToken $env:ENROLHQ_API_TOKEN

function Limit-Length { param([string]$Text, [int]$Max = 1024)
    if ($Text.Length -gt $Max) { $Text.Substring(0, $Max) } else { $Text } }

$results = foreach ($profileId in $payload.profiles) {
    try {
        $r = Sync-ProfileToSis -ProfileId $profileId          # shared via profile.ps1
    }
    catch {                                                   # never drop a profile
        $r = @{ IsSuccess = $false; Error = $_.Exception.Message; Warning = '' }
    }
    $row = @{
        student_profile = $profileId
        is_success      = [bool]$r.IsSuccess
        error           = Limit-Length ([string]$r.Error)
        warning         = Limit-Length ([string]$r.Warning)
    }
    if ($r.ExternalId)              { $row.external_id                 = $r.ExternalId }
    if ($r.UserParentExternalId)    { $row.user_parent_external_id     = $r.UserParentExternalId }
    if ($r.NonUserParentExternalId) { $row.non_user_parent_external_id = $r.NonUserParentExternalId }
    $row
}

$body = @{
    sync_request     = $payload.sync_request
    student_profiles = @($results)
}

# Optional SIS import file — a data URI with a mandatory `filename:` segment.
$xml = Build-ExportXml -Results $results                        # your own; return '' for none
if ($xml) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($xml)
    $body.export_file = 'data:text/xml;filename:export.xml;base64,' + [Convert]::ToBase64String($bytes)
}

Invoke-EnrolHQRequest -Method POST -Endpoint 'integrations/sync/finished/' -Body $body
Write-Host "Reported sync_request $($payload.sync_request): $($results.Count) profiles"
```

Things this gets right, and that are easy to get wrong:

- **Every requested profile appears in `student_profiles`.** A crash on one
  profile must still produce a row, or the whole callback is rejected for set
  mismatch and the request stays unanswered forever.
- **Acknowledge before working** on the async protocol, so the `SyncRequest`
  isn't rolled back. Queueing the payload and returning is what makes that
  possible in a Function App, where nothing runs after the response is sent.
- **Never `500`** on the legacy protocol — report failures in `errors` with a
  `200`.
- **`school_domain` from the payload**, never a hardcoded host.
- **Constant-time token comparison**, checked before any work.
- **Connect once per invocation**, not per profile — every `Connect-EnrolHQ`
  hits the rate-limited `accounts/refresh/` endpoint (see the README's
  "Rate limiting" section).

The same design works in C# with the SDK: an HTTP-triggered function that
enqueues, and a queue-triggered function that builds `EnrolHQClient.FromBaseUrl`
from `school_domain`, reads profiles with `client.Applications`, and posts the
result with `client.Http.PostAsync("integrations/sync/finished/", body)`.

---

## 8. Local testing

EnrolHQ ships a built-in simulator on non-production builds. Point **Integration
Service URL** at the school's own instance:

```
http://localhost:8000/api/v1/integrations/simulate/
```

It mirrors both protocols: with no `sync_request` it returns a canned legacy
body (with a `test.xml` export); with one, it queues a background task that
posts a synthetic response back to `integrations/sync/finished/` after ~2s —
alternating `is_success` per profile so you can see both branches. The
background workers must be running for the async path.

Going the other way — testing *your* service against real EnrolHQ signals —
put its public URL in the field (for local development, a tunnel such as
`func start` plus a dev tunnel or ngrok), set a token, and trigger a sync
from a student profile (**Sync <SIS>** > *Synchronous sync*), then read the
Call Log or the sync log for what EnrolHQ made of your response.
