using System.Text.Json.Serialization;

namespace EnrolHQ.SDK.Models;

/// <summary>Application document.</summary>
public class ApplicationDocument
{
    [JsonPropertyName("id")]
    public string Id { get; init; } = "";

    [JsonPropertyName("file")]
    public string? File { get; init; }

    [JsonPropertyName("filename")]
    public string Filename { get; init; } = "";

    [JsonPropertyName("student_profile")]
    public string? StudentProfile { get; init; }

    [JsonPropertyName("parent")]
    public string? Parent { get; init; }

    [JsonPropertyName("group")]
    public string? Group { get; init; }

    [JsonPropertyName("group_kind")]
    public string? GroupKind { get; init; }

    [JsonPropertyName("created_at")]
    public string? CreatedAt { get; init; }

    [JsonPropertyName("staff")]
    public string? Staff { get; init; }

    [JsonPropertyName("user")]
    public string? User { get; init; }

    [JsonPropertyName("is_submitted")]
    public bool? IsSubmitted { get; init; }

    [JsonPropertyName("is_verified")]
    public bool? IsVerified { get; init; }
}
