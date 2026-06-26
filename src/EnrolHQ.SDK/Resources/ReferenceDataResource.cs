using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>Access reference/lookup data (campuses, countries, languages, etc.).</summary>
public class ReferenceDataResource : BaseResource
{
    public ReferenceDataResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>
    /// Returns all application status settings: per-status labels and flags
    /// (<c>application_status</c>, <c>status_label</c>, <c>default_status_label</c>,
    /// <c>is_status_enabled</c>, <c>is_parent_dashboard_stage_visible</c>, ...),
    /// keyed to the <see cref="Models.Enums.ApplicationStatus"/> enum.
    /// </summary>
    public Task<List<JsonElement>> ApplicationStatusSettingsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("application-status-settings/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all school campuses.</summary>
    public Task<List<Campus>> CampusesAsync(CancellationToken ct = default)
        => ListAllAsync<Campus>("school-campuses/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all attendance types.</summary>
    public Task<List<JsonElement>> AttendanceTypesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("attendance-types/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all countries.</summary>
    public Task<List<JsonElement>> CountriesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/countries/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all languages.</summary>
    public Task<List<JsonElement>> LanguagesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/languages/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all nationalities.</summary>
    public Task<List<JsonElement>> NationalitiesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/nationalities/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all school options.</summary>
    public Task<List<JsonElement>> SchoolOptionsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/school-options/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all social units.</summary>
    public Task<List<JsonElement>> SocialUnitsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/social-units/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all suburbs, optionally filtered by query parameters.</summary>
    public Task<List<JsonElement>> SuburbsAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/suburbs/", queryParams, 1000, ct);

    /// <summary>Returns all timezones.</summary>
    public Task<List<JsonElement>> TimezonesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/timezones/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all medical condition options.</summary>
    public Task<List<JsonElement>> MedicalConditionOptionsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("medical-condition-options/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all parent relationship types.</summary>
    public Task<List<JsonElement>> ParentRelationshipsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("parents-relationships/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all profile categories.</summary>
    public Task<List<JsonElement>> ProfileCategoriesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("profile-categories/", pageSize: 1000, cancellationToken: ct);

    /// <summary>Returns all profile category options.</summary>
    public Task<List<JsonElement>> ProfileCategoryOptionsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("profile-category-options/", pageSize: 1000, cancellationToken: ct);
}
