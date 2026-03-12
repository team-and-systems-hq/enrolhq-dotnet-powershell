# Azure Integration

This guide covers running EnrolHQ PowerShell workloads on Azure Automation, Azure
Functions, and integrating with Azure Key Vault for secret management.

---

## Azure Automation

### Creating the Automation Account

```powershell
# Create a resource group (skip if you already have one)
New-AzResourceGroup -Name 'rg-enrolhq-automation' -Location 'australiaeast'

# Create the Automation Account with a system-assigned managed identity
New-AzAutomationAccount -Name 'aa-enrolhq' `
    -ResourceGroupName 'rg-enrolhq-automation' `
    -Location 'australiaeast' `
    -AssignSystemIdentity
```

### Uploading the Module

**Option A — Upload a zip file through the portal:**

1. Build the module locally:
   ```powershell
   ./build.ps1
   ```
2. The build produces `publish/EnrolHQ.PowerShell.zip`.
3. In the Azure Portal, navigate to *Automation Account > Modules > Add a module*.
4. Upload the zip and select **Runtime version 7.2** (PowerShell 7).

**Option B — Install from a NuGet feed:**

```powershell
New-AzAutomationModule -AutomationAccountName 'aa-enrolhq' `
    -ResourceGroupName 'rg-enrolhq-automation' `
    -Name 'EnrolHQ.PowerShell' `
    -ContentLinkUri 'https://pkgs.dev.azure.com/team-and-systems-hq/_packaging/your-feed/nuget/v2/package/EnrolHQ.PowerShell/1.0.0' `
    -RuntimeVersion '7.2'
```

### Creating Runbook Credentials

Store the EnrolHQ API token as an Automation credential asset:

```powershell
$tokenSecure = ConvertTo-SecureString 'ekt_live_...' -AsPlainText -Force
$credential  = New-Object System.Management.Automation.PSCredential('yourschool', $tokenSecure)

New-AzAutomationCredential -AutomationAccountName 'aa-enrolhq' `
    -ResourceGroupName 'rg-enrolhq-automation' `
    -Name 'EnrolHQ-Credential' `
    -Value $credential
```

The **Username** field holds the EnrolHQ instance name; the **Password** field holds the
API token.

### Scheduling Runbooks

```powershell
# Create a schedule — daily at 06:00 AEST
$params = @{
    AutomationAccountName = 'aa-enrolhq'
    ResourceGroupName     = 'rg-enrolhq-automation'
    Name                  = 'Daily-0600-AEST'
    StartTime             = (Get-Date '06:00').AddDays(1)
    TimeZone              = 'AUS Eastern Standard Time'
    DayInterval           = 1
}
New-AzAutomationSchedule @params

# Link the schedule to a runbook
Register-AzAutomationScheduledRunbook -AutomationAccountName 'aa-enrolhq' `
    -ResourceGroupName 'rg-enrolhq-automation' `
    -RunbookName 'Sync-EnrolHQApplications' `
    -ScheduleName 'Daily-0600-AEST'
```

### Webhook Triggers

Create a webhook so external systems (e.g., EnrolHQ event notifications) can trigger a
runbook on demand:

```powershell
$webhook = New-AzAutomationWebhook -AutomationAccountName 'aa-enrolhq' `
    -ResourceGroupName 'rg-enrolhq-automation' `
    -RunbookName 'Process-EnrolHQWebhook' `
    -Name 'enrolhq-webhook' `
    -IsEnabled $true `
    -ExpiryTime (Get-Date).AddYears(1) `
    -Force

# Save this URI securely — it is only shown once
Write-Output "Webhook URI: $($webhook.WebhookURI)"
```

### Example Runbook — Sync Applications to CSV

```powershell
# Runbook: Sync-EnrolHQApplications.ps1
# Runtime: PowerShell 7.2

#Requires -Modules EnrolHQ.PowerShell, Az.Storage

param()

# --- Authenticate -----------------------------------------------------------
$cred = Get-AutomationPSCredential -Name 'EnrolHQ-Credential'
Connect-EnrolHQ -Instance $cred.UserName `
                -ApiToken ($cred.Password | ConvertFrom-SecureString -AsPlainText)

# --- Fetch data --------------------------------------------------------------
$apps = Get-EnrolHQApplications -EntryYear (Get-Date).Year -All
Write-Output "Retrieved $($apps.Count) applications."

# --- Export to CSV ------------------------------------------------------------
$csvPath = Join-Path $env:TEMP 'enrolhq-applications.csv'
$apps | Export-Csv -Path $csvPath -NoTypeInformation

# --- Upload to Azure Blob Storage (optional) ---------------------------------
$ctx = New-AzStorageContext -StorageAccountName 'stschooldata' `
                            -StorageAccountKey (Get-AutomationVariable -Name 'StorageKey')

Set-AzStorageBlobContent -Container 'exports' `
                         -File $csvPath `
                         -Blob "applications/applications-$(Get-Date -Format 'yyyyMMdd').csv" `
                         -Context $ctx `
                         -Force

Write-Output "Export complete."
```

### Example Runbook — Process Webhook Event

```powershell
# Runbook: Process-EnrolHQWebhook.ps1
# Runtime: PowerShell 7.2

#Requires -Modules EnrolHQ.PowerShell

param(
    [Parameter(Mandatory)]
    [object] $WebhookData
)

$payload = $WebhookData.RequestBody | ConvertFrom-Json

Write-Output "Received event: $($payload.event_type) for resource $($payload.resource_id)"

# Authenticate
$cred = Get-AutomationPSCredential -Name 'EnrolHQ-Credential'
Connect-EnrolHQ -Instance $cred.UserName `
                -ApiToken ($cred.Password | ConvertFrom-SecureString -AsPlainText)

switch ($payload.event_type) {
    'application.submitted' {
        $app = Get-EnrolHQApplication -Id $payload.resource_id
        # ... process application ...
        Write-Output "Processed application $($app.id) for $($app.first_name) $($app.last_name)."
    }
    'application.updated' {
        $app = Get-EnrolHQApplication -Id $payload.resource_id
        # ... sync application record ...
        Write-Output "Synced application $($app.id)."
    }
    default {
        Write-Warning "Unhandled event type: $($payload.event_type)"
    }
}
```

---

## Azure Functions

### PowerShell Worker Project Structure

```
enrolhq-functions/
├── host.json
├── requirements.psd1
├── profile.ps1
├── Sync-Students/
│   ├── function.json
│   └── run.ps1
└── Webhook-Handler/
    ├── function.json
    └── run.ps1
```

### requirements.psd1

Declare the module dependency so Azure Functions installs it automatically on cold start:

```powershell
@{
    'Az.KeyVault'         = '5.*'
    'EnrolHQ.PowerShell'  = '1.*'
}
```

> **Note:** The module must be published to the PowerShell Gallery or a registered feed
> for managed dependencies to resolve it. For private modules, bundle the module in
> the `Modules/` folder of your function app instead.

### profile.ps1

```powershell
# Runs once when the function worker starts
if ($env:MSI_SECRET) {
    # Running in Azure with Managed Identity — authenticate to Azure services
    Connect-AzAccount -Identity | Out-Null
}
```

### Timer Trigger — Daily Application Sync

**function.json:**

```json
{
  "bindings": [
    {
      "name": "Timer",
      "type": "timerTrigger",
      "direction": "in",
      "schedule": "0 0 6 * * *"
    }
  ]
}
```

**run.ps1:**

```powershell
param($Timer)

# Retrieve API token from Key Vault via Managed Identity
$token = Get-AzKeyVaultSecret -VaultName 'kv-school-secrets' `
                               -Name 'EnrolHQ-ApiToken' `
                               -AsPlainText

Connect-EnrolHQ -Instance $env:ENROLHQ_INSTANCE -ApiToken $token

$apps = Get-EnrolHQApplications -EntryYear (Get-Date).Year -All
Write-Host "Synced $($apps.Count) application records."

# ... further processing ...
```

### HTTP Trigger — Webhook Handler

**function.json:**

```json
{
  "bindings": [
    {
      "authLevel": "function",
      "name": "Request",
      "type": "httpTrigger",
      "direction": "in",
      "methods": ["post"]
    },
    {
      "name": "Response",
      "type": "http",
      "direction": "out"
    }
  ]
}
```

**run.ps1:**

```powershell
param($Request, $TriggerMetadata)

$payload = $Request.Body

$token = Get-AzKeyVaultSecret -VaultName 'kv-school-secrets' `
                               -Name 'EnrolHQ-ApiToken' `
                               -AsPlainText
Connect-EnrolHQ -Instance $env:ENROLHQ_INSTANCE -ApiToken $token

switch ($payload.event_type) {
    'application.submitted' {
        $app = Get-EnrolHQApplication -Id $payload.resource_id
        # ... handle new application ...
    }
    default {
        Write-Warning "Unknown event: $($payload.event_type)"
    }
}

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [System.Net.HttpStatusCode]::OK
    Body       = @{ status = 'processed' } | ConvertTo-Json
})
```

### Managed Identity for Key Vault Access

1. Enable **System-assigned managed identity** on the Function App.
2. Grant the identity access to Key Vault:

```powershell
# Get the Function App's managed identity principal ID
$principalId = (Get-AzFunctionApp -Name 'func-enrolhq' `
    -ResourceGroupName 'rg-enrolhq').IdentityPrincipalId

# Grant "Key Vault Secrets User" role
New-AzRoleAssignment -ObjectId $principalId `
    -RoleDefinitionName 'Key Vault Secrets User' `
    -Scope (Get-AzKeyVault -VaultName 'kv-school-secrets').ResourceId
```

3. Ensure the Key Vault uses **Azure RBAC** for its permission model (recommended) or
   add an access policy for the identity.

---

## Azure Key Vault Integration

### Storing API Tokens

```powershell
# Store the token
$secretValue = ConvertTo-SecureString 'ekt_live_...' -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName 'kv-school-secrets' `
                     -Name 'EnrolHQ-ApiToken' `
                     -SecretValue $secretValue `
                     -ContentType 'text/plain' `
                     -Tag @{ application = 'EnrolHQ'; environment = 'production' }
```

### Accessing from Automation

In an Azure Automation runbook, the Automation Account's managed identity must have
access to the Key Vault:

```powershell
# Authenticate with the Automation Account's managed identity
Connect-AzAccount -Identity

$token = Get-AzKeyVaultSecret -VaultName 'kv-school-secrets' `
                               -Name 'EnrolHQ-ApiToken' `
                               -AsPlainText

Connect-EnrolHQ -Instance 'yourschool' -ApiToken $token
```

### Accessing from Functions

See the Managed Identity section above. The `profile.ps1` calls `Connect-AzAccount
-Identity` on startup, and individual functions call `Get-AzKeyVaultSecret` to retrieve
the token.

### Key Vault Best Practices

- Enable **soft delete** and **purge protection** on the vault.
- Use **Azure RBAC** rather than vault access policies for granular control.
- Enable **diagnostic logging** and forward logs to a Log Analytics workspace.
- Set secret **expiry dates** and create alerts for upcoming expirations.
- Store the **instance name** as a Key Vault secret or as an app setting /
  Automation variable — it is not a secret, but centralising configuration simplifies
  management.

---

**Related guides:**

- [Authentication](Authentication.md) — all credential methods
- [Installation](Installation.md) — uploading the module to Azure Automation
- [Publishing](Publishing.md) — publishing to a private feed for managed dependencies
