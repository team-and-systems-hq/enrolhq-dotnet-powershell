using System.Text.Json;
using EnrolHQ.SDK.Http;

namespace EnrolHQ.SDK.Resources;

/// <summary>Read-only access to email history.</summary>
public class EmailLogResource : BaseResource
{
    public EmailLogResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Returns all email log entries for a student profile, automatically paginating through every page.</summary>
    /// <param name="studentProfileId">The student profile UUID.</param>
    public Task<List<JsonElement>> ListAllAsync(string studentProfileId,
        int pageSize = 1000, CancellationToken ct = default)
        => ListAllAsync<JsonElement>("email-log/",
            new Dictionary<string, string?> { ["student_profile"] = studentProfileId },
            pageSize, ct);
}
