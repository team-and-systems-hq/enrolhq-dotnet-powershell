using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>Interact with student applications.</summary>
public class ApplicationsResource : BaseResource
{
    public ApplicationsResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Returns a single page of student profiles.</summary>
    public Task<PaginatedResponse<StudentProfile>> ListPageAsync(
        Dictionary<string, string?>? filters = null, int page = 1, int pageSize = 100,
        CancellationToken ct = default)
        => ListPageAsync<StudentProfile>("applications-list/", filters, page, pageSize, ct);

    /// <summary>Returns all student profiles, automatically paginating through every page.</summary>
    public Task<List<StudentProfile>> ListAllAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<StudentProfile>("applications-list/", filters, pageSize, ct);

    /// <summary>Returns the total number of applications matching the given filters.</summary>
    public async Task<int> CountAsync(Dictionary<string, string?>? filters = null, CancellationToken ct = default)
    {
        var result = await Http.GetAsync<CountResponse>("applications-list/count/", filters, ct)
            .ConfigureAwait(false);
        return result.Count;
    }

    /// <summary>Retrieves a single application by its identifier.</summary>
    /// <param name="applicationId">The application/student profile UUID.</param>
    public Task<JsonElement> GetAsync(string applicationId, CancellationToken ct = default)
        => Http.GetAsync<JsonElement>($"applications/{applicationId}/", cancellationToken: ct);

    /// <summary>Creates a new application.</summary>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> CreateAsync(object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("applications/", data, cancellationToken: ct);

    /// <summary>Updates an existing application.</summary>
    /// <param name="applicationId">The application/student profile UUID.</param>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> UpdateAsync(string applicationId, object data, CancellationToken ct = default)
        => await Http.PutAsync<JsonElement>($"applications/{applicationId}/", data, ct);

    /// <summary>Attaches a student profile to an existing parent/family.</summary>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> AttachAsync(object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("applications/attach/", data, cancellationToken: ct);

    /// <summary>Changes the application status for one or more applications.</summary>
    /// <param name="applicationIds">The application UUIDs whose status should change.</param>
    /// <param name="status">The target status code.</param>
    public Task ChangeStatusAsync(IEnumerable<string> applicationIds, int status,
        CancellationToken ct = default)
        => Http.PostAsync("applications-list/change_status/",
            new { application_status = status },
            new Dictionary<string, string?> { ["id__in"] = string.Join(",", applicationIds) }, ct);

    /// <summary>Sends an email to the contacts of an application.</summary>
    /// <param name="applicationId">The application/student profile UUID.</param>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> SendMailAsync(string applicationId, object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/send_mail/", data, cancellationToken: ct);

    /// <summary>Toggles the favourite/starred flag on an application.</summary>
    /// <param name="applicationId">The application/student profile UUID.</param>
    public async Task<JsonElement> ToggleFavoriteAsync(string applicationId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/toggle_favorite/", cancellationToken: ct);

    /// <summary>Books an interview for the specified application.</summary>
    /// <param name="applicationId">The application/student profile UUID.</param>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> BookInterviewAsync(string applicationId, object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/book_interview/", data, cancellationToken: ct);

    /// <summary>Cancels an existing interview booking for the specified application.</summary>
    /// <param name="applicationId">The application/student profile UUID.</param>
    public async Task<JsonElement> CancelInterviewAsync(string applicationId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/cancel_interview_booking/", cancellationToken: ct);

    /// <summary>Sends an enrolment invite to the parent of the specified application.</summary>
    /// <param name="applicationId">The application/student profile UUID.</param>
    public async Task<JsonElement> SendEnrolmentInviteAsync(string applicationId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/send_enrolment_invite/", cancellationToken: ct);

    /// <summary>Records a parent-initiated decline for the specified application.</summary>
    /// <param name="applicationId">The application/student profile UUID.</param>
    public async Task<JsonElement> DeclineByParentAsync(string applicationId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/decline_student_by_parent/", cancellationToken: ct);

    /// <summary>Records a staff-initiated decline for the specified application.</summary>
    /// <param name="applicationId">The application/student profile UUID.</param>
    public async Task<JsonElement> DeclineByStaffAsync(string applicationId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"applications/{applicationId}/decline_student_by_staff/", cancellationToken: ct);

    /// <summary>Sends a bulk email to applications matching the given filters.</summary>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public Task BulkSendEmailAsync(object data, Dictionary<string, string?>? filters = null, CancellationToken ct = default)
        => Http.PostAsync("applications-list/bulk_send_email/", data, filters, ct);

    /// <summary>Adds a note in bulk to applications matching the given filters.</summary>
    /// <param name="text">The note text to attach.</param>
    public Task BulkNoteAsync(string text, Dictionary<string, string?>? filters = null, CancellationToken ct = default)
        => Http.PostAsync("applications-list/bulk_note/", new { text }, filters, ct);

    /// <summary>Closes applications in bulk that match the given filters.</summary>
    public Task BulkCloseAsync(Dictionary<string, string?>? filters = null, CancellationToken ct = default)
        => Http.PostAsync("applications-list/bulk_close/", queryParams: filters, cancellationToken: ct);

    /// <summary>Merges two student profiles into one.</summary>
    /// <param name="profileToKeep">UUID of the profile to keep.</param>
    /// <param name="profileNotToKeep">UUID of the profile to discard.</param>
    /// <param name="swapParents">If true, swap parent records from the discarded profile.</param>
    public async Task<JsonElement> MergeProfilesAsync(string profileToKeep, string profileNotToKeep,
        bool swapParents = false, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("applications-list/merge_profiles/", new
        {
            profile_to_keep = profileToKeep,
            profile_not_to_keep = profileNotToKeep,
            is_profile_not_to_keep_parents_swapped = swapParents,
        }, cancellationToken: ct);
}
