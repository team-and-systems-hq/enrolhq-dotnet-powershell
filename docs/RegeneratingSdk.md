# Regenerating / Updating the SDK

This guide explains why the EnrolHQ SDK is handwritten and how to update it when the
EnrolHQ API changes.

---

## Why the SDK Is Handwritten

The EnrolHQ C# SDK is **not generated** from an OpenAPI specification. This was a
deliberate decision for several reasons:

1. **Tailored developer experience.** Auto-generated clients tend to expose raw HTTP
   concepts and produce verbose, generic code. A handwritten SDK lets us provide
   idiomatic C# types, fluent builders, and PowerShell-friendly output objects.

2. **Stable public surface.** Generated code changes with every schema revision, even
   for cosmetic API changes. A handwritten SDK allows us to absorb non-breaking API
   changes internally without altering the public interface.

3. **Selective coverage.** We only wrap the API endpoints and fields that are relevant to
   the PowerShell module's use cases. This keeps the SDK lean and easy to maintain.

4. **Custom authentication logic.** The token-refresh flow, retry policies, and error
   mapping are specific to EnrolHQ and are simpler to implement by hand than to retrofit
   onto a generated client.

> **Trade-off:** The cost is that API changes must be applied manually. The process
> below makes this straightforward.

---

## Update Process

When EnrolHQ releases a new API version or adds/modifies endpoints, follow these steps:

### Step 1 — Download the Latest OpenAPI Spec

Obtain the latest specification from EnrolHQ:

```bash
# If EnrolHQ publishes the spec at a known URL
curl -o specs/openapi-latest.json \
    https://yourschool.enrolhq.com.au/api/v2/schema/

# Or download manually from the EnrolHQ admin panel
```

Keep a versioned copy:

```bash
cp specs/openapi-latest.json specs/openapi-$(date +%Y%m%d).json
```

### Step 2 — Diff Against the Previous Version

Compare the new spec with the version the SDK was last updated against:

```bash
# Human-readable diff
diff --unified specs/openapi-previous.json specs/openapi-latest.json | less

# Or use a structured OpenAPI diff tool
npx openapi-diff specs/openapi-previous.json specs/openapi-latest.json
```

**Useful tools for diffing specs:**

| Tool | Install | Notes |
|------|---------|-------|
| [`openapi-diff`](https://github.com/OpenAPITools/openapi-diff) | `npx openapi-diff` or Docker | Detects breaking vs. non-breaking changes |
| [`oasdiff`](https://github.com/Tufin/oasdiff) | `brew install oasdiff` | Breaking-change detection, changelog generation |
| [`dyff`](https://github.com/homeport/dyff) | `brew install dyff` | Generic YAML/JSON diff with colour output |
| VS Code | Built-in | Open both files and use *Compare Active File With...* |

**Example using `oasdiff`:**

```bash
# Show all changes
oasdiff diff specs/openapi-previous.json specs/openapi-latest.json

# Show only breaking changes
oasdiff breaking specs/openapi-previous.json specs/openapi-latest.json

# Generate a changelog
oasdiff changelog specs/openapi-previous.json specs/openapi-latest.json
```

### Step 3 — Add or Update Resource Methods

Based on the diff, update the SDK:

| Change type | Action |
|-------------|--------|
| New endpoint | Create a new method in the appropriate `Resources/` class, or create a new resource class |
| Modified endpoint (new optional parameter) | Add an optional parameter to the existing method |
| Modified endpoint (changed response shape) | Update the corresponding model in `Models/` |
| Removed endpoint | Mark the method as `[Obsolete]` first, then remove in the next major version |
| New authentication scope | Update `Authentication/` classes |

**File locations:**

```
src/EnrolHQ.SDK/
├── Authentication/    ← token refresh, auth header logic
├── Exceptions/        ← API error types
├── Http/              ← base HTTP client, retry, rate limiting
├── Models/            ← request/response DTOs and enums
│   └── Enums/
└── Resources/         ← one class per API resource (Applications, Events, Staff, etc.)
```

**Example — adding a new endpoint:**

```csharp
// src/EnrolHQ.SDK/Resources/ApplicationsResource.cs

/// <summary>
/// GET /api/v2/applications/{id}/siblings/
/// Added in API version 2026-03.
/// </summary>
public async Task<List<StudentProfile>> GetSiblingsAsync(
    string applicationId,
    CancellationToken cancellationToken = default)
{
    return await _client.GetAsync<List<StudentProfile>>(
        $"applications/{applicationId}/siblings/",
        cancellationToken);
}
```

### Step 4 — Add or Update Models

If the API introduces new fields or new object types:

```csharp
// src/EnrolHQ.SDK/Models/Sibling.cs
using System.Text.Json.Serialization;

namespace EnrolHQ.SDK.Models;

public sealed class Sibling
{
    [JsonPropertyName("id")]
    public string Id { get; init; } = string.Empty;

    [JsonPropertyName("first_name")]
    public string FirstName { get; init; } = string.Empty;

    [JsonPropertyName("last_name")]
    public string LastName { get; init; } = string.Empty;

    [JsonPropertyName("entry_year")]
    public int? EntryYear { get; init; }
}
```

If existing models gain new optional fields, simply add the property:

```csharp
// Add to StudentProfile.cs
[JsonPropertyName("preferred_name")]
public string? PreferredName { get; init; }
```

### Step 5 — Update Tests

Every new or changed method must have corresponding tests:

```csharp
// tests/EnrolHQ.SDK.Tests/SerializationTests.cs (add a new test)

[Fact]
public void Should_Deserialize_Sibling()
{
    var json = """
    {
        "id": "app-sibling-001",
        "first_name": "Jane",
        "last_name": "Doe",
        "entry_year": 2027
    }
    """;

    var sibling = JsonSerializer.Deserialize<Sibling>(json, _options);

    sibling.Should().NotBeNull();
    sibling!.FirstName.Should().Be("Jane");
    sibling.EntryYear.Should().Be(2027);
}
```

Update the PowerShell Pester tests as well:

```powershell
# tests/EnrolHQ.PowerShell.Tests/Get-EnrolHQApplicationSiblings.Tests.ps1

Describe 'Get-EnrolHQApplicationSiblings' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../src/EnrolHQ.PowerShell" -Force
    }

    It 'returns siblings for a given application' {
        Mock Invoke-EnrolHQRestMethod {
            @(
                @{ id = 'app-sibling-001'; first_name = 'Jane'; last_name = 'Doe' }
            )
        } -ModuleName EnrolHQ.PowerShell

        # Example — adjust to match the actual cmdlet you create
        $result = Invoke-EnrolHQRequest -Method GET -Endpoint "applications/app-001/siblings/"
        $result | Should -HaveCount 1
        $result[0].first_name | Should -Be 'Jane'
    }
}
```

---

## Checking for Breaking Changes

Before releasing a new SDK version, verify backward compatibility:

1. **API-level breaking changes** — detected in Step 2 using `oasdiff breaking`.
2. **SDK-level breaking changes** — check whether you renamed types, removed public
   methods, or changed method signatures. These require a major version bump.
3. **PowerShell-level breaking changes** — check whether cmdlet names, parameter names,
   or output object shapes changed. Use `Get-Command` and `Get-Help` to audit.

### Quick Checklist

- [ ] Downloaded and archived the latest OpenAPI spec.
- [ ] Diffed the spec and identified all changes.
- [ ] Added/updated resource methods in `Resources/`.
- [ ] Added/updated models in `Models/`.
- [ ] Added/updated PowerShell cmdlets in `src/EnrolHQ.PowerShell/Public/`.
- [ ] Added/updated C# unit tests.
- [ ] Added/updated Pester tests.
- [ ] Ran `dotnet test` — all green.
- [ ] Ran `Invoke-Pester` — all green.
- [ ] Updated version number in `.psd1` and `.csproj`.
- [ ] Updated the previous spec file: `cp specs/openapi-latest.json specs/openapi-previous.json`.
- [ ] Committed and created a pull request.

---

**Related guides:**

- [Publishing](Publishing.md) — releasing the updated SDK
- [Installation](Installation.md) — verifying the new version
