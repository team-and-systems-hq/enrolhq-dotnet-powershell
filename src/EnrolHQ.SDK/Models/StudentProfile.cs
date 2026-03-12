using System.Text.Json.Serialization;

namespace EnrolHQ.SDK.Models;

/// <summary>Student profile (list view) from applications-list endpoint.</summary>
public class StudentProfile
{
    [JsonPropertyName("id")]
    public string Id { get; init; } = "";

    [JsonPropertyName("application_status")]
    public int ApplicationStatus { get; init; }

    [JsonPropertyName("first_name")]
    public string FirstName { get; init; } = "";

    [JsonPropertyName("last_name")]
    public string LastName { get; init; } = "";

    [JsonPropertyName("preferred_name")]
    public string? PreferredName { get; init; }

    [JsonPropertyName("dob")]
    public string? Dob { get; init; }

    [JsonPropertyName("gender")]
    public int? Gender { get; init; }

    [JsonPropertyName("gender_other")]
    public string? GenderOther { get; init; }

    [JsonPropertyName("entry_grade")]
    public int? EntryGrade { get; init; }

    [JsonPropertyName("entry_year")]
    public int? EntryYear { get; init; }

    [JsonPropertyName("entry_term")]
    public int? EntryTerm { get; init; }

    [JsonPropertyName("campus")]
    public object? Campus { get; init; }

    [JsonPropertyName("attendance_type")]
    public object? AttendanceType { get; init; }

    [JsonPropertyName("external_id")]
    public string? ExternalId { get; init; }

    [JsonPropertyName("is_favorite")]
    public bool? IsFavorite { get; init; }

    [JsonPropertyName("how_hear")]
    public string? HowHear { get; init; }

    [JsonPropertyName("created_at")]
    public string? CreatedAt { get; init; }

    [JsonPropertyName("updated_at")]
    public string? UpdatedAt { get; init; }

    [JsonPropertyName("user_parent")]
    public ParentSummary? UserParent { get; init; }

    [JsonPropertyName("non_user_parent")]
    public ParentSummary? NonUserParent { get; init; }
}

/// <summary>Parent summary embedded in student profile.</summary>
public class ParentSummary
{
    [JsonPropertyName("id")]
    public string? Id { get; init; }

    [JsonPropertyName("email")]
    public string? Email { get; init; }

    [JsonPropertyName("first_name")]
    public string? FirstName { get; init; }

    [JsonPropertyName("last_name")]
    public string? LastName { get; init; }

    [JsonPropertyName("title")]
    public string? Title { get; init; }

    [JsonPropertyName("mobile_phone")]
    public string? MobilePhone { get; init; }
}
