using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>List and add notes on student profiles.</summary>
public class NotesResource : BaseResource
{
    public NotesResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Returns all notes for a student profile, automatically paginating through every page.</summary>
    /// <param name="studentProfileId">The student profile UUID.</param>
    public Task<List<Note>> ListAllAsync(string studentProfileId,
        int pageSize = 1000, CancellationToken ct = default)
        => ListAllAsync<Note>("notes/",
            new Dictionary<string, string?> { ["student_profile"] = studentProfileId },
            pageSize, ct);

    /// <summary>Creates a new note on a student profile.</summary>
    /// <param name="studentProfileId">The student profile UUID.</param>
    /// <param name="text">The note text.</param>
    public Task<Note?> CreateAsync(string studentProfileId, string text, CancellationToken ct = default)
        => Http.PostAsync<Note>("notes/",
            new { student_profile = studentProfileId, text },
            cancellationToken: ct);
}
