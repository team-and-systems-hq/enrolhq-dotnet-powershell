using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>Manage application documents.</summary>
public class DocumentsResource : BaseResource
{
    public DocumentsResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Returns all documents for a student profile, automatically paginating through every page.</summary>
    /// <param name="studentProfileId">The student profile UUID.</param>
    public Task<List<ApplicationDocument>> ListAllAsync(string studentProfileId,
        int pageSize = 1000, CancellationToken ct = default)
        => ListAllAsync<ApplicationDocument>("application-documents/",
            new Dictionary<string, string?> { ["student_profile"] = studentProfileId },
            pageSize, ct);

    /// <summary>Returns a single page of documents for a student profile.</summary>
    /// <param name="studentProfileId">The student profile UUID.</param>
    public Task<PaginatedResponse<ApplicationDocument>> ListPageAsync(string studentProfileId,
        int page = 1, int pageSize = 100, CancellationToken ct = default)
        => ListPageAsync<ApplicationDocument>("application-documents/",
            new Dictionary<string, string?> { ["student_profile"] = studentProfileId },
            page, pageSize, ct);

    /// <summary>Upload a document. Uses ByteArrayContent so retries are safe.</summary>
    public async Task<ApplicationDocument?> UploadAsync(string studentProfileId, string filePath,
        string groupKind, string? filename = null, CancellationToken ct = default)
    {
        filename ??= Path.GetFileName(filePath);
        var fileBytes = await File.ReadAllBytesAsync(filePath, ct).ConfigureAwait(false);

        using var content = new MultipartFormDataContent();
        content.Add(new StringContent(filename), "filename");
        content.Add(new StringContent(groupKind), "group_kind");
        content.Add(new StringContent(studentProfileId), "student_profile");
        content.Add(new ByteArrayContent(fileBytes), "file", filename);

        return await Http.PostMultipartAsync<ApplicationDocument>("application-documents/", content, ct)
            .ConfigureAwait(false);
    }

    /// <summary>Downloads a document from the given URL and saves it to disk.</summary>
    /// <param name="documentUrl">The absolute URL of the document to download.</param>
    /// <param name="destPath">The local file path where the document will be saved.</param>
    public async Task DownloadAsync(string documentUrl, string destPath, CancellationToken ct = default)
    {
        var dir = Path.GetDirectoryName(destPath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        var response = await Http.GetRawAsync(documentUrl, ct).ConfigureAwait(false);
        await using var stream = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
        await using var file = File.Create(destPath);
        await stream.CopyToAsync(file, ct).ConfigureAwait(false);
    }

    /// <summary>Deletes a document by its identifier.</summary>
    /// <param name="documentId">The document UUID.</param>
    public Task DeleteAsync(string documentId, CancellationToken ct = default)
        => Http.DeleteAsync($"application-documents/{documentId}/", ct);
}
