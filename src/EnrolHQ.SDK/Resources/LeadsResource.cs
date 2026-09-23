using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using EnrolHQ.SDK.Exceptions;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>
/// Interact with leads (pre-enquiry contacts) and lead references.
/// <para>
/// A lead captures a contact (parent) and optionally a prospective student
/// before a full application exists. Key payload fields:
/// <list type="bullet">
/// <item><c>email</c>, <c>title</c>, <c>first_name</c>, <c>last_name</c>,
/// <c>mobile_phone</c>, <c>home_phone</c>, <c>business_phone</c> — contact details.</item>
/// <item><c>reference</c> — a lead reference UUID identifying which form/source
/// the lead came from (see <see cref="ReferencesAsync"/>).</item>
/// <item><c>student</c> — nested object: <c>first_name</c>, <c>last_name</c>,
/// <c>dob</c>, <c>entry_grade</c>, <c>entry_year</c>, <c>campus</c>, <c>comment</c>,
/// <c>questions</c>, <c>questions_other</c>.</item>
/// <item><c>residential_address</c> — nested object: <c>apartment</c>,
/// <c>street_address</c>, <c>city</c>, <c>suburb</c>, <c>state</c>, <c>postcode</c>,
/// <c>country</c>.</item>
/// <item><c>student_profile</c> — a student profile UUID. Set this to link the
/// lead to an existing application/profile; leave null for a standalone lead.</item>
/// <item><c>how_hear</c> / <c>how_hear_other</c> — marketing attribution.</item>
/// </list>
/// Replaces the legacy v1 Zapier <c>POST /api/v1/leads/</c> integration.
/// </para>
/// </summary>
public class LeadsResource : BaseResource
{
    public LeadsResource(EnrolHQHttpClient http) : base(http) { }

    // ── List / Get ──────────────────────────────────────────────

    /// <summary>Returns a single page of leads.</summary>
    /// <param name="filters">
    /// Optional filters. Supported: <c>is_email_unique</c> and
    /// <c>has_student_profile</c> (both <c>"true"</c> / <c>"false"</c>).
    /// </param>
    public Task<PaginatedResponse<JsonElement>> ListPageAsync(
        Dictionary<string, string?>? filters = null, int page = 1, int pageSize = 100,
        CancellationToken ct = default)
        => ListPageAsync<JsonElement>("leads/", filters, page, pageSize, ct);

    /// <summary>Returns all leads matching the filters, automatically paginating through every page.</summary>
    /// <param name="filters">
    /// Optional filters. Supported: <c>is_email_unique</c> and
    /// <c>has_student_profile</c> (both <c>"true"</c> / <c>"false"</c>).
    /// </param>
    public Task<List<JsonElement>> ListAllAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<JsonElement>("leads/", filters, pageSize, ct);

    /// <summary>Retrieves full detail for a single lead.</summary>
    /// <param name="leadId">The lead UUID.</param>
    public Task<JsonElement> GetAsync(string leadId, CancellationToken ct = default)
        => Http.GetAsync<JsonElement>($"leads/{leadId}/", cancellationToken: ct);

    // ── Create / Update ─────────────────────────────────────────

    /// <summary>Creates a new lead.</summary>
    /// <param name="data">
    /// Request body — see the class summary for the payload shape. To link the
    /// lead to an existing application, set <c>student_profile</c> to the
    /// profile's UUID.
    /// </param>
    public async Task<JsonElement> CreateAsync(object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("leads/", data, cancellationToken: ct).ConfigureAwait(false);

    /// <summary>Full-replacement update (PUT) of a lead.</summary>
    /// <remarks>
    /// WARNING: this is a PUT, not a PATCH. Send the complete lead object —
    /// omitted fields may be reset to defaults. Recommended pattern:
    /// <see cref="GetAsync"/> → modify → <see cref="UpdateAsync"/>.
    /// </remarks>
    /// <param name="leadId">The lead UUID.</param>
    /// <param name="data">The complete lead object.</param>
    public async Task<JsonElement> UpdateAsync(string leadId, object data, CancellationToken ct = default)
        => await Http.PutAsync<JsonElement>($"leads/{leadId}/", data, ct).ConfigureAwait(false);

    // ── Lead References ─────────────────────────────────────────

    /// <summary>
    /// Returns all lead references as a flat list. Use a record's
    /// <see cref="LeadReference.Id"/> as the <c>reference</c> field when
    /// creating or updating a lead.
    /// </summary>
    public Task<List<LeadReference>> ReferencesAsync(int pageSize = 1000, CancellationToken ct = default)
        => ListAllAsync<LeadReference>("lead-references/", pageSize: pageSize, cancellationToken: ct);

    /// <summary>
    /// Creates a new lead reference and returns it with its server-assigned id.
    /// </summary>
    /// <remarks>
    /// Lead references have no dedicated write endpoint — they live on the
    /// school settings object, so this round-trips <c>school/</c>:
    /// get → append to <c>lead_references</c> → put → re-read.
    /// </remarks>
    /// <param name="name">Display name for the reference.</param>
    /// <param name="slug">URL slug; defaults to a slugified <paramref name="name"/>.</param>
    /// <param name="confirmationRedirectUrl">
    /// Where the public form redirects after submission (empty for the default
    /// confirmation page).
    /// </param>
    /// <exception cref="ArgumentException">A lead reference with the same slug already exists. Nothing is written.</exception>
    /// <exception cref="EnrolHQException">The reference is missing when read back after saving.</exception>
    public async Task<LeadReference> CreateReferenceAsync(string name, string? slug = null,
        string confirmationRedirectUrl = "", CancellationToken ct = default)
    {
        slug ??= Slugify(name);

        var school = await Http.GetAsync<JsonObject>("school/", cancellationToken: ct).ConfigureAwait(false);

        if (school["lead_references"] is not JsonArray references)
        {
            references = new JsonArray();
            school["lead_references"] = references;
        }

        foreach (var existing in references)
        {
            if (string.Equals(SlugOf(existing), slug, StringComparison.Ordinal))
                throw new ArgumentException($"A lead reference with slug '{slug}' already exists", nameof(slug));
        }

        references.Add(new JsonObject
        {
            ["name"] = name,
            ["slug"] = slug,
            ["confirmation_redirect_url"] = confirmationRedirectUrl,
            ["is_removable"] = true,
        });

        await Http.PutAsync<JsonElement>("school/", school, ct).ConfigureAwait(false);

        var saved = await ReferencesAsync(ct: ct).ConfigureAwait(false);
        return saved.FirstOrDefault(r => string.Equals(r.Slug, slug, StringComparison.Ordinal))
            ?? throw new EnrolHQException($"Lead reference '{slug}' was not found after saving school settings");
    }

    private static string? SlugOf(JsonNode? reference)
        => reference is JsonObject obj
            && obj["slug"] is JsonValue value
            && value.TryGetValue<string>(out var slug)
            ? slug
            : null;

    /// <summary>Lower-cases <paramref name="name"/>, collapses non-alphanumeric runs to '-' and trims.</summary>
    internal static string Slugify(string name)
        => Regex.Replace(name.ToLowerInvariant(), "[^a-z0-9]+", "-").Trim('-');
}
