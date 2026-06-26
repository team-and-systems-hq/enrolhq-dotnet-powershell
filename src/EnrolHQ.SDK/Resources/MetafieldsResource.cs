using System.Text.Json;
using EnrolHQ.SDK.Http;

namespace EnrolHQ.SDK.Resources;

/// <summary>
/// Access field configuration ("metafields") for the school.
/// <para>
/// The read-only <c>metafields/</c> endpoint describes how each field on each
/// model (<c>student</c>, <c>parent</c>, <c>doctor</c>, <c>guardian</c>,
/// <c>emergency_contact</c>, <c>medical_data</c>, ...) is configured. For every
/// field there is a <c>label</c> plus <c>enabled</c> and <c>mandatory</c> maps
/// keyed by scope: <c>enr</c> (enrolment form), <c>eoi</c> (GPA / EOI form),
/// <c>enq</c> (enquiry form), <c>evt</c> (event booking), <c>cust</c> (custom
/// form), and <c>admin</c> (admin view; <c>enabled</c> only).
/// </para>
/// </summary>
public class MetafieldsResource : BaseResource
{
    public MetafieldsResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Gets the full metafields object.</summary>
    /// <returns>
    /// An object with <c>field_settings</c> (the school's configured fields)
    /// and <c>default_field_settings</c> (the platform defaults).
    /// </returns>
    public Task<JsonElement> GetAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("metafields/", queryParams, ct);

    /// <summary>Returns only the configured <c>field_settings</c> map (by model).</summary>
    public async Task<JsonElement> FieldSettingsAsync(CancellationToken ct = default)
    {
        var root = await GetAsync(ct: ct).ConfigureAwait(false);
        return root.TryGetProperty("field_settings", out var settings) ? settings : default;
    }

    /// <summary>Returns only the <c>default_field_settings</c> map (platform defaults).</summary>
    public async Task<JsonElement> DefaultFieldSettingsAsync(CancellationToken ct = default)
    {
        var root = await GetAsync(ct: ct).ConfigureAwait(false);
        return root.TryGetProperty("default_field_settings", out var settings) ? settings : default;
    }
}
