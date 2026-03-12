using System.Text.Json;
using EnrolHQ.SDK.Http;

namespace EnrolHQ.SDK.Resources;

/// <summary>List and create activity log entries.</summary>
public class ActivityLogResource : BaseResource
{
    public ActivityLogResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Returns all activity log entries for a student profile, automatically paginating through every page.</summary>
    /// <param name="studentProfileId">The student profile UUID.</param>
    public Task<List<JsonElement>> ListAllAsync(string studentProfileId,
        int pageSize = 1000, CancellationToken ct = default)
        => ListAllAsync<JsonElement>("activity-log/",
            new Dictionary<string, string?> { ["student_profile"] = studentProfileId },
            pageSize, ct);

    /// <summary>Creates a new activity log entry on a student profile.</summary>
    /// <param name="studentProfileId">The student profile UUID.</param>
    /// <param name="text">The activity log entry text.</param>
    public async Task<JsonElement> CreateAsync(string studentProfileId, string text,
        CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("activity-log/",
            new { student_profile = studentProfileId, text },
            cancellationToken: ct);
}
