using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>Interact with student applications.</summary>
public class ApplicationsResource : BaseResource
{
    public ApplicationsResource(EnrolHQHttpClient http) : base(http) { }

    public Task<PaginatedResponse<StudentProfile>> ListPageAsync(
        Dictionary<string, string?>? filters = null, int page = 1, int pageSize = 100,
        CancellationToken ct = default)
        => ListPageAsync<StudentProfile>("applications-list/", filters, page, pageSize, ct);

    public Task<List<StudentProfile>> ListAllAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<StudentProfile>("applications-list/", filters, pageSize, ct);

    public async Task<int> CountAsync(Dictionary<string, string?>? filters = null, CancellationToken ct = default)
    {
        var result = await Http.GetAsync<CountResponse>("applications-list/count/", filters, ct)
            .ConfigureAwait(false);
        return result.Count;
    }

    public Task<JsonElement> GetAsync(string applicationId, CancellationToken ct = default)
        => Http.GetAsync<JsonElement>($"applications/{applicationId}/", cancellationToken: ct);

    public async Task<JsonElement> CreateAsync(object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("applications/", data, cancellationToken: ct);

    public async Task<JsonElement> UpdateAsync(string applicationId, object data, CancellationToken ct = default)
        => await Http.PutAsync<JsonElement>($"applications/{applicationId}/", data, ct);

    public async Task<JsonElement> AttachAsync(object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("applications/attach/", data, cancellationToken: ct);

    public Task ChangeStatusAsync(IEnumerable<string> applicationIds, int status,
        CancellationToken ct = default)
        => Http.PostAsync("applications-list/change_status/",
            new { application_status = status },
            new Dictionary<string, string?> { ["id__in"] = string.Join(",", applicationIds) }, ct);

    public async Task<JsonElement> SendMailAsync(string applicationId, object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/send_mail/", data, cancellationToken: ct);

    public async Task<JsonElement> ToggleFavoriteAsync(string applicationId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/toggle_favorite/", cancellationToken: ct);

    public async Task<JsonElement> BookInterviewAsync(string applicationId, object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/book_interview/", data, cancellationToken: ct);

    public async Task<JsonElement> CancelInterviewAsync(string applicationId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/cancel_interview_booking/", cancellationToken: ct);

    public async Task<JsonElement> SendEnrolmentInviteAsync(string applicationId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/send_enrolment_invite/", cancellationToken: ct);

    public async Task<JsonElement> DeclineByParentAsync(string applicationId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/decline_student_by_parent/", cancellationToken: ct);

    public async Task<JsonElement> DeclineByStaffAsync(string applicationId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/decline_student_by_staff/", cancellationToken: ct);

    public Task BulkSendEmailAsync(object data, Dictionary<string, string?>? filters = null, CancellationToken ct = default)
        => Http.PostAsync("applications-list/bulk_send_email/", data, filters, ct);

    public Task BulkNoteAsync(string text, Dictionary<string, string?>? filters = null, CancellationToken ct = default)
        => Http.PostAsync("applications-list/bulk_note/", new { text }, filters, ct);

    public Task BulkCloseAsync(Dictionary<string, string?>? filters = null, CancellationToken ct = default)
        => Http.PostAsync("applications-list/bulk_close/", queryParams: filters, cancellationToken: ct);

    public async Task<JsonElement> MergeProfilesAsync(string profileToKeep, string profileNotToKeep,
        bool swapParents = false, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("applications-list/merge_profiles/", new
        {
            profile_to_keep = profileToKeep,
            profile_not_to_keep = profileNotToKeep,
            is_profile_not_to_keep_parents_swapped = swapParents,
        }, cancellationToken: ct);
}
