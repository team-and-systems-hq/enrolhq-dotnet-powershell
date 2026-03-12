using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>Access reference/lookup data (campuses, countries, languages, etc.).</summary>
public class ReferenceDataResource : BaseResource
{
    public ReferenceDataResource(EnrolHQHttpClient http) : base(http) { }

    public Task<List<Campus>> CampusesAsync(CancellationToken ct = default)
        => ListAllAsync<Campus>("school-campuses/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> AttendanceTypesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("attendance-types/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> CountriesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/countries/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> LanguagesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/languages/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> NationalitiesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/nationalities/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> SchoolOptionsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/school-options/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> SocialUnitsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/social-units/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> SuburbsAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/suburbs/", queryParams, 1000, ct);

    public Task<List<JsonElement>> TimezonesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("dictionaries/timezones/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> MedicalConditionOptionsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("medical-condition-options/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> ParentRelationshipsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("parents-relationships/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> ProfileCategoriesAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("profile-categories/", pageSize: 1000, cancellationToken: ct);

    public Task<List<JsonElement>> ProfileCategoryOptionsAsync(CancellationToken ct = default)
        => ListAllAsync<JsonElement>("profile-category-options/", pageSize: 1000, cancellationToken: ct);
}
