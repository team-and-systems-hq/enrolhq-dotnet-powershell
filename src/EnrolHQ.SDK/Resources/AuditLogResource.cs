using System.Text.Json;
using EnrolHQ.SDK.Http;

namespace EnrolHQ.SDK.Resources;

/// <summary>
/// Read the audit / change log for a student profile or parent.
/// <para>
/// The <c>audit/log/</c> endpoint is read-only and uses cursor pagination
/// (no total count). Each entry has a list of human-readable <c>changes</c>,
/// plus <c>updated_at</c> and <c>updated_by</c>. Filter by exactly one subject
/// — a student profile or a parent.
/// </para>
/// </summary>
public class AuditLogResource : BaseResource
{
    public AuditLogResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>
    /// Returns all audit-log entries for a student profile, automatically
    /// following every cursor page.
    /// </summary>
    /// <param name="studentProfileId">The student profile UUID.</param>
    public Task<List<JsonElement>> ListByStudentProfileAsync(string studentProfileId,
        int pageSize = 25, CancellationToken ct = default)
        => Http.GetAllCursorPagesAsync<JsonElement>("audit/log/",
            new Dictionary<string, string?> { ["student_profile"] = studentProfileId },
            pageSize, cancellationToken: ct);

    /// <summary>
    /// Returns all audit-log entries for a parent, automatically following
    /// every cursor page.
    /// </summary>
    /// <param name="parentId">The parent UUID.</param>
    public Task<List<JsonElement>> ListByParentAsync(string parentId,
        int pageSize = 25, CancellationToken ct = default)
        => Http.GetAllCursorPagesAsync<JsonElement>("audit/log/",
            new Dictionary<string, string?> { ["parent"] = parentId },
            pageSize, cancellationToken: ct);
}
