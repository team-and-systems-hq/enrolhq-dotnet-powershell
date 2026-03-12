using System.Text.Json.Serialization;

namespace EnrolHQ.SDK.Models;

/// <summary>Staff member.</summary>
public class StaffMember
{
    [JsonPropertyName("id")]
    public string Id { get; init; } = "";

    [JsonPropertyName("email")]
    public string Email { get; init; } = "";

    [JsonPropertyName("first_name")]
    public string FirstName { get; init; } = "";

    [JsonPropertyName("last_name")]
    public string LastName { get; init; } = "";

    [JsonPropertyName("is_active")]
    public bool IsActive { get; init; }

    [JsonPropertyName("mobile_phone")]
    public string? MobilePhone { get; init; }

    [JsonPropertyName("roles")]
    public List<Role>? Roles { get; init; }

    [JsonPropertyName("is_email_password_auth_enabled")]
    public bool? IsEmailPasswordAuthEnabled { get; init; }
}

/// <summary>Staff role.</summary>
public class Role
{
    [JsonPropertyName("id")]
    public string? Id { get; init; }

    [JsonPropertyName("name")]
    public string Name { get; init; } = "";

    [JsonPropertyName("groups")]
    public List<string>? Groups { get; init; }
}
