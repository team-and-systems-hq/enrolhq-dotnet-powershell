using System.Text.Json.Serialization;

namespace EnrolHQ.SDK.Models;

/// <summary>
/// Lead reference: identifies which form/source a lead came from.
/// Use a record's <see cref="Id"/> as the <c>reference</c> field when creating
/// or updating a lead.
/// </summary>
public class LeadReference
{
    [JsonPropertyName("id")]
    public string Id { get; init; } = "";

    [JsonPropertyName("name")]
    public string Name { get; init; } = "";

    [JsonPropertyName("slug")]
    public string? Slug { get; init; }

    [JsonPropertyName("confirmation_redirect_url")]
    public string? ConfirmationRedirectUrl { get; init; }

    [JsonPropertyName("is_removable")]
    public bool? IsRemovable { get; init; }
}
