using System.Runtime.CompilerServices;
using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>
/// Custom forms and the submissions parents make against them.
/// <para>
/// Custom forms (medical updates, permission/consent forms, transition surveys,
/// scholarship registrations) are the mechanism schools use to collect data
/// that has no dedicated field on the application. Their answers are
/// <b>not</b> returned by <see cref="ApplicationsResource.ListAllAsync"/> — see
/// <see cref="AnswersAsync"/>.
/// </para>
/// <para>
/// A submit stores answers in two places:
/// <list type="bullet">
/// <item><c>payload</c> — answers to the form's own questions (radio, checkbox,
/// text, signature, ...). This is where consent/permission answers live.</item>
/// <item><c>initial_payload</c> — the profile data pre-filled into the form when
/// it was opened, plus blank slots for the form's own questions.</item>
/// </list>
/// Elements listed in <see cref="ProfileBackedElements"/> (emergency contacts,
/// medical data, parent contacts) are written back onto the student profile on
/// submission, so the authoritative current value for those lives on
/// <see cref="ApplicationsResource.GetAsync"/>, not on the submit.
/// </para>
/// </summary>
public class FormsResource : BaseResource
{
    /// <summary>
    /// Element types whose answers are written back onto the student profile
    /// rather than being stored in the submit's <c>payload</c>.
    /// </summary>
    public static readonly IReadOnlySet<string> ProfileBackedElements = new HashSet<string>(StringComparer.Ordinal)
    {
        "EMERGENCY_CONTACTS",
        "MEDICAL_DATA",
        "PARENT_1_CONTACTS",
        "PARENT_2_CONTACTS",
        "GUARDIAN_CONTACTS",
        "DOCUMENTS",
    };

    /// <summary>Element types that carry no answer (layout/content only).</summary>
    private static readonly HashSet<string> ContentElements = new(StringComparer.Ordinal)
    {
        "HTML", "HEADER", "DIVIDER", "IMAGE",
    };

    /// <summary>Element types a permission/consent form uses for its yes/no answers.</summary>
    private static readonly HashSet<string> ConsentElements = new(StringComparer.Ordinal)
    {
        "RADIO", "CHECKBOX", "CHECKBOX_GROUP",
    };

    public FormsResource(EnrolHQHttpClient http) : base(http) { }

    // ── Form definitions ────────────────────────────────────────

    /// <summary>Returns a single page of form definitions (<c>forms/staff/</c>).</summary>
    public Task<PaginatedResponse<JsonElement>> ListPageAsync(
        Dictionary<string, string?>? filters = null, int page = 1, int pageSize = 100,
        CancellationToken ct = default)
        => ListPageAsync<JsonElement>("forms/staff/", filters, page, pageSize, ct);

    /// <summary>
    /// Returns every form defined for the school, automatically paginating
    /// through every page.
    /// </summary>
    /// <remarks>
    /// Includes both custom forms and the built-in stub forms (enquiry, event
    /// booking, ...). Each record has <c>id</c>, <c>title</c>, <c>form_slug</c>,
    /// <c>kind</c>, <c>is_active</c> and <c>is_private</c>. Filter on
    /// <c>kind == "CUSTOM"</c> for the school's own forms.
    /// </remarks>
    public Task<List<JsonElement>> ListAllAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<JsonElement>("forms/staff/", filters, pageSize, ct);

    /// <summary>Returns published (parent-facing) custom forms only (<c>forms/</c>).</summary>
    /// <remarks>
    /// Unlike <see cref="ListAllAsync"/> this returns the parent-facing view,
    /// which includes the form's audience rules (<c>allowed_entry_years</c>,
    /// <c>allowed_entry_grades</c>, <c>allowed_application_statuses</c>,
    /// <c>allowed_campuses</c>) and payment settings.
    /// </remarks>
    public Task<List<JsonElement>> PublishedAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<JsonElement>("forms/", filters, pageSize, ct);

    /// <summary>Gets a single published form by its <c>form_slug</c>.</summary>
    /// <remarks>Note this endpoint is keyed by <b>slug</b>, not UUID.</remarks>
    public Task<JsonElement> GetAsync(string formSlug, CancellationToken ct = default)
        => Http.GetAsync<JsonElement>($"forms/{formSlug}/", cancellationToken: ct);

    /// <summary>
    /// Returns the first form whose title or slug matches (case-insensitive),
    /// or null if nothing matches.
    /// </summary>
    /// <remarks>Convenience for looking up a form's UUID when you only know its name.</remarks>
    public async Task<JsonElement?> FindAsync(string titleOrSlug, CancellationToken ct = default)
    {
        var needle = titleOrSlug.Trim().ToLowerInvariant();
        var forms = await ListAllAsync(pageSize: 1000, ct: ct).ConfigureAwait(false);
        foreach (var form in forms)
        {
            var title = (GetString(form, "title") ?? "").ToLowerInvariant();
            var slug = (GetString(form, "form_slug") ?? "").ToLowerInvariant();
            if (needle == title || needle == slug)
                return form;
        }
        return null;
    }

    // ── Submits ─────────────────────────────────────────────────

    /// <summary>Returns a single page of form submissions (<c>forms/staff-submits/</c>).</summary>
    /// <param name="filters">See <see cref="SubmitsAllAsync"/> for the supported filters.</param>
    public Task<PaginatedResponse<JsonElement>> SubmitsPageAsync(
        Dictionary<string, string?>? filters = null, int page = 1, int pageSize = 100,
        CancellationToken ct = default)
        => ListPageAsync<JsonElement>("forms/staff-submits/", filters, page, pageSize, ct);

    /// <summary>
    /// Returns all form submissions matching the filters, automatically
    /// paginating through every page.
    /// </summary>
    /// <param name="filters">
    /// Supported filters (confirmed against the API):
    /// <c>form</c> — a form UUID (note: <b>not</b> <c>form_id</c>, even though the
    /// field is called <c>form_id</c> in the response); <c>entry_year</c>,
    /// <c>entry_grade</c>, <c>application_statuses</c>; <c>is_completed</c> —
    /// <c>"true"</c> for submitted, <c>"false"</c> for started but not finished.
    /// </param>
    /// <remarks>
    /// Records are summaries (<c>form_id</c>, <c>created_at</c>, <c>completed_at</c>,
    /// <c>form_pdf</c>, nested <c>student_profile</c>). They carry <b>neither the
    /// answers nor the submit's own id</b>, so you cannot feed them straight into
    /// <see cref="GetSubmitAsync"/>. To get answers in bulk, either use
    /// <see cref="ExportSubmitsAsync"/> (one request, everything flattened) or
    /// <see cref="IterateAnswersAsync"/>, which walks <c>student_profile.id</c>
    /// back through the application detail.
    /// </remarks>
    public Task<List<JsonElement>> SubmitsAllAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<JsonElement>("forms/staff-submits/", filters, pageSize, ct);

    /// <summary>Gets a single submission including <c>payload</c>, <c>initial_payload</c> and <c>form_schema</c>.</summary>
    /// <param name="submitId">The submit UUID.</param>
    public Task<JsonElement> GetSubmitAsync(string submitId, CancellationToken ct = default)
        => Http.GetAsync<JsonElement>($"forms/staff-submits/{submitId}/", cancellationToken: ct);

    /// <summary>Returns every submission for one application, with full payloads.</summary>
    /// <remarks>
    /// The <c>forms/staff-submits/</c> endpoint has no per-application filter,
    /// so this reads the submit ids off the application detail and fetches each
    /// one. Each returned submit is annotated with <see cref="FormSubmit.FormId"/>
    /// and <see cref="FormSubmit.ApplicationId"/> — the submit detail endpoint
    /// does not include them (its <c>form_schema.id</c> is a schema
    /// <em>version</em> id, not the form's id).
    /// </remarks>
    /// <param name="applicationId">UUID of the application.</param>
    /// <param name="form">Optional form UUID to return submissions for that form only.</param>
    public async Task<List<FormSubmit>> SubmitsForApplicationAsync(string applicationId, string? form = null,
        CancellationToken ct = default)
    {
        var application = await Http.GetAsync<JsonElement>($"applications/{applicationId}/", cancellationToken: ct)
            .ConfigureAwait(false);

        var submits = new List<FormSubmit>();
        if (application.ValueKind != JsonValueKind.Object
            || !application.TryGetProperty("custom_form_submits", out var entries)
            || entries.ValueKind != JsonValueKind.Array)
            return submits;

        foreach (var entry in entries.EnumerateArray())
        {
            if (entry.ValueKind != JsonValueKind.Object)
                continue;

            var formId = GetString(entry, "form");
            if (form is not null && formId != form)
                continue;

            var submitId = GetString(entry, "id");
            if (string.IsNullOrEmpty(submitId))
                continue;

            var detail = await GetSubmitAsync(submitId, ct).ConfigureAwait(false);
            submits.Add(new FormSubmit
            {
                Id = submitId,
                FormId = formId,
                ApplicationId = applicationId,
                CompletedAt = GetString(detail, "completed_at"),
                Detail = detail,
            });
        }
        return submits;
    }

    /// <summary>Returns labelled answers for one application's submissions.</summary>
    /// <param name="applicationId">UUID of the application.</param>
    /// <param name="form">Optional form UUID to return submissions for that form only.</param>
    public Task<List<FormAnswerRecord>> AnswersForApplicationAsync(string applicationId, string? form = null,
        CancellationToken ct = default)
        => BuildRecordsAsync(applicationId, form, studentProfile: null, ct);

    /// <summary>Yields labelled answers for every submission matching the filters.</summary>
    /// <remarks>
    /// Accepts the same filters as <see cref="SubmitsAllAsync"/>. Each record
    /// carries the summary's <see cref="FormAnswerRecord.StudentProfile"/>.
    /// This makes one request per matching application, because the submits
    /// list omits the submit id. For a large export prefer
    /// <see cref="ExportSubmitsAsync"/>, which returns the same data flattened
    /// to CSV in a single request.
    /// <para>
    /// The filters choose <em>which applications</em> are visited; every
    /// submission of the form for each of those applications is then returned
    /// (the same behaviour as the Python SDK's <c>iter_answers</c>). If a parent
    /// has both a completed and an unfinished submission, both come back —
    /// check <see cref="FormAnswerRecord.CompletedAt"/> when you need only
    /// completed ones.
    /// </para>
    /// </remarks>
    /// <param name="form">Optional form UUID; added to <paramref name="filters"/> as <c>form</c>.</param>
    public async IAsyncEnumerable<FormAnswerRecord> IterateAnswersAsync(string? form = null,
        Dictionary<string, string?>? filters = null, int pageSize = 100,
        [EnumeratorCancellation] CancellationToken ct = default)
    {
        var allFilters = filters is null
            ? new Dictionary<string, string?>()
            : new Dictionary<string, string?>(filters);
        if (form is not null)
            allFilters["form"] = form;

        var summaries = await SubmitsAllAsync(allFilters, pageSize, ct).ConfigureAwait(false);

        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var summary in summaries)
        {
            if (summary.ValueKind != JsonValueKind.Object
                || !summary.TryGetProperty("student_profile", out var profile)
                || profile.ValueKind != JsonValueKind.Object)
                continue;

            var profileId = GetString(profile, "id");
            if (string.IsNullOrEmpty(profileId) || !seen.Add(profileId))
                continue;

            var records = await BuildRecordsAsync(profileId, form, profile, ct).ConfigureAwait(false);
            foreach (var record in records)
                yield return record;
        }
    }

    /// <summary>Overwrites a submission's <c>payload</c> (staff edit).</summary>
    /// <remarks>
    /// WARNING: this replaces the whole payload. Read it with
    /// <see cref="GetSubmitAsync"/> first, modify, then write it back.
    /// </remarks>
    /// <param name="submitId">The submit UUID.</param>
    /// <param name="payload">The complete new payload object.</param>
    public async Task<JsonElement> UpdateSubmitAsync(string submitId, object payload, CancellationToken ct = default)
        => await Http.PutAsync<JsonElement>($"forms/staff-submits/{submitId}/", new { payload }, ct)
            .ConfigureAwait(false);

    /// <summary>Re-opens a completed submission so the parent can edit it again.</summary>
    /// <param name="submitId">The submit UUID.</param>
    public async Task<JsonElement> ReopenSubmitAsync(string submitId, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>($"forms/staff-submits/{submitId}/re_open/", cancellationToken: ct)
            .ConfigureAwait(false);

    /// <summary>Downloads the form-submits report as CSV.</summary>
    /// <remarks>
    /// Accepts the same filters as <see cref="SubmitsAllAsync"/>. One flat row
    /// per submission (student details, emergency contacts, medical data and
    /// every answer) in a single request — the fastest path for a bulk load.
    /// </remarks>
    /// <param name="destPath">Local file path to write the CSV to. Parent directories are created.</param>
    /// <returns><paramref name="destPath"/>.</returns>
    public async Task<string> ExportSubmitsAsync(string destPath, Dictionary<string, string?>? filters = null,
        CancellationToken ct = default)
    {
        var url = Http.BuildUrl("forms/staff-submits/export/", filters);
        using var response = await Http.GetRawAsync(url, ct).ConfigureAwait(false);

        var dir = Path.GetDirectoryName(destPath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        await using var stream = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
        await using var file = File.Create(destPath);
        await stream.CopyToAsync(file, ct).ConfigureAwait(false);
        return destPath;
    }

    // ── Answers ─────────────────────────────────────────────────

    /// <summary>Returns a submission's answers flattened and labelled.</summary>
    /// <remarks>
    /// Joins the raw <c>payload</c> against the form's schema so each answer
    /// carries the question text a parent actually saw, instead of an opaque
    /// key like <c>group_3_social_media</c>. Returns one record per answerable
    /// element, in form order. Layout-only elements (HTML blocks, dividers) are
    /// skipped. Elements flagged <see cref="FormAnswer.IsProfileBacked"/> are
    /// copies of profile data taken when the form was opened — read the
    /// application detail for their current value.
    /// </remarks>
    /// <param name="submitId">The submit UUID.</param>
    public async Task<List<FormAnswer>> AnswersAsync(string submitId, CancellationToken ct = default)
        => AnswersFrom(await GetSubmitAsync(submitId, ct).ConfigureAwait(false));

    /// <summary>Flattens and labels an already-fetched submit (see <see cref="AnswersAsync"/>).</summary>
    /// <param name="submit">A <c>forms/staff-submits/{id}/</c> response.</param>
    public static List<FormAnswer> AnswersFrom(JsonElement submit)
    {
        // `payload` holds the parent's own answers; `initial_payload` holds the
        // profile data pre-filled at open time plus blanks for those answers.
        // Overlaying payload on initial_payload gives the final state.
        var values = new Dictionary<string, JsonElement>(StringComparer.Ordinal);
        if (submit.ValueKind == JsonValueKind.Object)
        {
            MergeObjectInto(values, submit, "initial_payload");
            MergeObjectInto(values, submit, "payload");
        }

        var results = new List<FormAnswer>();
        if (submit.ValueKind != JsonValueKind.Object
            || !submit.TryGetProperty("form_schema", out var formSchema)
            || formSchema.ValueKind != JsonValueKind.Object
            || !formSchema.TryGetProperty("schema", out var schema)
            || schema.ValueKind != JsonValueKind.Array)
            return results;

        foreach (var section in schema.EnumerateArray())
        {
            if (section.ValueKind != JsonValueKind.Object)
                continue;

            var sectionTitle = GetString(section, "title") ?? "";
            if (!section.TryGetProperty("elements", out var elements) || elements.ValueKind != JsonValueKind.Array)
                continue;

            foreach (var element in elements.EnumerateArray())
            {
                if (element.ValueKind != JsonValueKind.Object)
                    continue;

                var elementType = GetString(element, "element_type") ?? "";
                if (ContentElements.Contains(elementType))
                    continue;

                var name = GetString(element, "name");
                var value = name is not null && values.TryGetValue(name, out var found) ? found : default;

                results.Add(new FormAnswer
                {
                    Section = sectionTitle,
                    Name = name,
                    Label = (GetString(element, "label") ?? "").Trim(),
                    ElementType = elementType,
                    Value = value,
                    IsProfileBacked = ProfileBackedElements.Contains(elementType),
                });
            }
        }
        return results;
    }

    /// <summary>Returns only the yes/no consent answers from a submission, keyed by field name.</summary>
    /// <remarks>
    /// A permission/consent form models each permission as a RADIO or CHECKBOX
    /// element, so this filters <see cref="AnswersAsync"/> down to those.
    /// </remarks>
    /// <param name="submitId">The submit UUID.</param>
    public async Task<Dictionary<string, ConsentAnswer>> ConsentsAsync(string submitId, CancellationToken ct = default)
        => ConsentsFrom(await AnswersAsync(submitId, ct).ConfigureAwait(false));

    /// <summary>Narrows already-flattened answers to the yes/no consent answers, keyed by field name.</summary>
    public static Dictionary<string, ConsentAnswer> ConsentsFrom(IEnumerable<FormAnswer> answers)
    {
        var result = new Dictionary<string, ConsentAnswer>(StringComparer.Ordinal);
        foreach (var answer in answers)
        {
            if (answer.Name is not null && ConsentElements.Contains(answer.ElementType))
                result[answer.Name] = new ConsentAnswer { Label = answer.Label, Value = answer.Value };
        }
        return result;
    }

    // ── Helpers ─────────────────────────────────────────────────

    private async Task<List<FormAnswerRecord>> BuildRecordsAsync(string applicationId, string? form,
        JsonElement? studentProfile, CancellationToken ct)
    {
        var submits = await SubmitsForApplicationAsync(applicationId, form, ct).ConfigureAwait(false);
        var records = new List<FormAnswerRecord>(submits.Count);
        foreach (var submit in submits)
        {
            records.Add(new FormAnswerRecord
            {
                SubmitId = submit.Id,
                FormId = submit.FormId,
                CompletedAt = submit.CompletedAt,
                Answers = AnswersFrom(submit.Detail),
                StudentProfile = studentProfile,
            });
        }
        return records;
    }

    private static void MergeObjectInto(Dictionary<string, JsonElement> target, JsonElement parent, string property)
    {
        if (!parent.TryGetProperty(property, out var obj) || obj.ValueKind != JsonValueKind.Object)
            return;
        foreach (var prop in obj.EnumerateObject())
            target[prop.Name] = prop.Value;
    }

    private static string? GetString(JsonElement obj, string property)
        => obj.ValueKind == JsonValueKind.Object
            && obj.TryGetProperty(property, out var value)
            && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;
}
