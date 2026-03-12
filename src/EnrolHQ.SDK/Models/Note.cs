using System.Text.Json.Serialization;

namespace EnrolHQ.SDK.Models;

/// <summary>Student profile note.</summary>
public class Note
{
    [JsonPropertyName("id")]
    public string Id { get; init; } = "";

    [JsonPropertyName("created_at")]
    public string? CreatedAt { get; init; }

    [JsonPropertyName("created_by")]
    public string? CreatedBy { get; init; }

    [JsonPropertyName("is_pinned")]
    public bool IsPinned { get; init; }

    [JsonPropertyName("text")]
    public string Text { get; init; } = "";

    [JsonPropertyName("student_profile")]
    public string? StudentProfile { get; init; }

    [JsonPropertyName("event")]
    public string? Event { get; init; }
}
