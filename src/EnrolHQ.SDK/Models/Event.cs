using System.Text.Json.Serialization;

namespace EnrolHQ.SDK.Models;

/// <summary>Staff event.</summary>
public class StaffEvent
{
    [JsonPropertyName("id")]
    public string? Id { get; init; }

    [JsonPropertyName("slug")]
    public string? Slug { get; init; }

    [JsonPropertyName("name")]
    public string Name { get; init; } = "";

    [JsonPropertyName("kind")]
    public object? Kind { get; init; }

    [JsonPropertyName("campus")]
    public object? Campus { get; init; }

    [JsonPropertyName("description")]
    public string? Description { get; init; }

    [JsonPropertyName("location")]
    public string? Location { get; init; }

    [JsonPropertyName("is_enabled")]
    public bool? IsEnabled { get; init; }

    [JsonPropertyName("is_registration_enabled")]
    public bool? IsRegistrationEnabled { get; init; }

    [JsonPropertyName("max_attendees_per_booking")]
    public int? MaxAttendeesPerBooking { get; init; }

    [JsonPropertyName("sessions")]
    public List<EventSession>? Sessions { get; init; }
}

/// <summary>Event session (time slot).</summary>
public class EventSession
{
    [JsonPropertyName("id")]
    public string? Id { get; init; }

    [JsonPropertyName("name")]
    public string? Name { get; init; }

    [JsonPropertyName("date")]
    public string? Date { get; init; }

    [JsonPropertyName("start_time")]
    public string? StartTime { get; init; }

    [JsonPropertyName("end_time")]
    public string? EndTime { get; init; }

    [JsonPropertyName("capacity")]
    public int? Capacity { get; init; }

    [JsonPropertyName("is_fully_booked")]
    public bool? IsFullyBooked { get; init; }

    [JsonPropertyName("is_expired")]
    public bool? IsExpired { get; init; }
}

/// <summary>Event booking.</summary>
public class EventBooking
{
    [JsonPropertyName("id")]
    public string? Id { get; init; }

    [JsonPropertyName("created_at")]
    public string? CreatedAt { get; init; }

    [JsonPropertyName("custom_field_1")]
    public string? CustomField1 { get; init; }

    [JsonPropertyName("custom_field_2")]
    public string? CustomField2 { get; init; }

    [JsonPropertyName("custom_field_3")]
    public string? CustomField3 { get; init; }

    [JsonPropertyName("session_name")]
    public string? SessionName { get; init; }

    [JsonPropertyName("session_date")]
    public string? SessionDate { get; init; }
}
