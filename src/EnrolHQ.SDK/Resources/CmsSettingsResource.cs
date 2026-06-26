using System.Text.Json;
using EnrolHQ.SDK.Http;

namespace EnrolHQ.SDK.Resources;

/// <summary>
/// Access the school's CMS / form configuration settings.
/// <para>
/// The <c>cms-settings/</c> endpoint is read-only and returns a single
/// configuration object covering enquiry and event-booking copy, form labels,
/// terms &amp; conditions, parent-dashboard visibility flags, and the school
/// policy agreement items shown to applicants.
/// </para>
/// </summary>
public class CmsSettingsResource : BaseResource
{
    public CmsSettingsResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Gets the CMS settings configuration object.</summary>
    /// <returns>
    /// The full settings object (e.g. <c>event_booking</c>, <c>enquiry</c>,
    /// <c>enrolment_form_settings</c>, <c>parent_label</c>,
    /// <c>school_policy_agreement_items</c>).
    /// </returns>
    public Task<JsonElement> GetAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("cms-settings/", queryParams, ct);
}
