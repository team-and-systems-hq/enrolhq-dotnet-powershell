# Authentication

This guide explains how EnrolHQ API authentication works and the recommended ways to
supply credentials in different environments.

---

## How EnrolHQ Authentication Works

EnrolHQ uses a **two-step token flow**:

```
┌─────────────┐              ┌──────────────┐              ┌──────────────┐
│  Long-lived │  POST        │  Short-lived │  GET/        │   EnrolHQ    │
│  API Token  │ ──────────►  │ Access Token │  POST        │   API        │
│             │ /accounts/   │              │ ──────────►  │   Resources  │
│             │  refresh/    │              │              │              │
└─────────────┘              └──────────────┘              └──────────────┘
```

1. You obtain a **long-lived API token** from the EnrolHQ web interface.
2. The SDK exchanges that token for a **short-lived access token** by POSTing to
   `/accounts/refresh/` with an `Authorization: Token {apiToken}` header.
3. The access token is sent as an `Authorization: Token {accessToken}` header on every
   subsequent API call.
4. When the access token expires (or a 401 is received), the SDK automatically refreshes
   it using the original API token.

The `Connect-EnrolHQ` cmdlet handles steps 2-4 transparently. You only need to supply
the instance name and the long-lived API token.

---

## Getting Your API Token

1. Log in to **EnrolHQ** as an administrator.
2. Navigate to **Profile > API Token** (or *Settings > Integrations > API Token*
   depending on your EnrolHQ version).
3. Click **Generate Token**.
4. Copy the token immediately — it is only displayed once.

> **Important:** Treat this token like a password. Anyone with the token can access your
> EnrolHQ instance via the API.

---

## Authentication Methods

### 1. Environment Variables (Recommended for CI/CD)

Set two environment variables before running any cmdlets:

```powershell
$env:ENROLHQ_INSTANCE  = 'demo.enrolhq.com.au'
$env:ENROLHQ_API_TOKEN = 'ekt_live_...'
```

Then connect without parameters:

```powershell
Connect-EnrolHQ
```

The module reads `ENROLHQ_INSTANCE` and `ENROLHQ_API_TOKEN` automatically when no
explicit parameters are provided.

**Setting environment variables in different shells:**

```bash
# Bash / Zsh
export ENROLHQ_INSTANCE='demo.enrolhq.com.au'
export ENROLHQ_API_TOKEN='ekt_live_...'

# Windows Command Prompt
set ENROLHQ_INSTANCE=demo.enrolhq.com.au
set ENROLHQ_API_TOKEN=ekt_live_...
```

### 2. Explicit Parameters

Pass credentials directly to `Connect-EnrolHQ`:

```powershell
$token = Read-Host -AsSecureString 'Enter API token'

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken $token
```

Or with a plain-text token (acceptable for quick testing only):

```powershell
Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'ekt_live_...'
```

### 3. SecretManagement Module

The [Microsoft.PowerShell.SecretManagement](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/)
module provides a unified interface to secret stores (local vault, Azure Key Vault,
HashiCorp Vault, etc.).

```powershell
# One-time setup
Install-Module Microsoft.PowerShell.SecretManagement
Install-Module Microsoft.PowerShell.SecretStore   # local vault

Register-SecretVault -Name 'LocalStore' -ModuleName Microsoft.PowerShell.SecretStore

# Store the token
Set-Secret -Name 'EnrolHQ-ApiToken' -Secret 'ekt_live_...'

# Use it
$token = Get-Secret -Name 'EnrolHQ-ApiToken' -AsPlainText
Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken $token
```

### 4. Azure Key Vault

Use the `Az.KeyVault` module to retrieve secrets from Azure Key Vault:

```powershell
# Authenticate to Azure (interactive or managed identity)
Connect-AzAccount

# Retrieve the token
$secret = Get-AzKeyVaultSecret -VaultName 'kv-school-secrets' `
                                -Name 'EnrolHQ-ApiToken' `
                                -AsPlainText

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken $secret
```

This is the recommended approach for **Azure Automation** and **Azure Functions**
workloads. See [Azure Integration](AzureIntegration.md) for end-to-end examples.

### 5. Azure Automation Credentials

If you prefer Azure Automation's built-in credential store:

```powershell
# Inside a runbook
$cred = Get-AutomationPSCredential -Name 'EnrolHQ-ServiceAccount'

# The username field stores the instance; the password stores the API token
Connect-EnrolHQ -Instance $cred.UserName `
                -ApiToken ($cred.Password | ConvertFrom-SecureString -AsPlainText)
```

Create the credential asset in the Azure Portal under
*Automation Account > Shared Resources > Credentials* with:

| Field    | Value                    |
|----------|--------------------------|
| Username | Your EnrolHQ instance ID |
| Password | Your API token           |

---

## Security Best Practices

1. **Never hardcode tokens** in scripts or source control. Use environment variables,
   secret stores, or credential managers.

2. **Use `SecureString`** when passing tokens in PowerShell to prevent them from
   appearing in plain text in memory dumps and logs:

   ```powershell
   $secureToken = ConvertTo-SecureString 'ekt_live_...' -AsPlainText -Force
   Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken $secureToken
   ```

3. **Rotate tokens regularly.** Regenerate your API token in EnrolHQ periodically and
   update all consuming services.

4. **Use Managed Identity** in Azure environments where possible. A managed identity
   removes the need to store any credential — Azure handles authentication to Key Vault
   automatically.

5. **Limit token scope.** If EnrolHQ supports scoped tokens, issue tokens with the
   minimum permissions required for each integration.

6. **Audit API usage.** Review the EnrolHQ audit log periodically to detect unexpected
   API activity.

7. **Add `.env` to `.gitignore`.** If you use a `.env` file during local development,
   ensure it is excluded from version control.

---

## Session Lifecycle

After calling `Connect-EnrolHQ`, the session state (instance URL, access token, expiry)
is stored in a module-scoped variable. All subsequent cmdlets in the same PowerShell
session use this state automatically.

```powershell
# Connect once
Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken $token

# All subsequent calls use the established session
$apps = Get-EnrolHQApplications -EntryYear 2026 -All
$app  = Get-EnrolHQApplication -Id 'app-001'
```

To disconnect or switch instances:

```powershell
Disconnect-EnrolHQ

# Connect to a different instance
Connect-EnrolHQ -Instance 'other.enrolhq.com.au' -ApiToken $otherToken
```

---

**Next step:** [Azure Integration](AzureIntegration.md) or jump straight to the
[README](../README.md) for a cmdlet reference.
