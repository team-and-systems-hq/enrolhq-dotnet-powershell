using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>Manage staff members.</summary>
public class StaffResource : BaseResource
{
    public StaffResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Returns a single page of staff members.</summary>
    public Task<PaginatedResponse<StaffMember>> ListPageAsync(
        Dictionary<string, string?>? filters = null, int page = 1, int pageSize = 100,
        CancellationToken ct = default)
        => ListPageAsync<StaffMember>("staff/", filters, page, pageSize, ct);

    /// <summary>Returns all staff members, automatically paginating through every page.</summary>
    public Task<List<StaffMember>> ListAllAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<StaffMember>("staff/", filters, pageSize, ct);

    /// <summary>Retrieves a single staff member by their identifier.</summary>
    /// <param name="staffId">The staff member UUID.</param>
    public Task<JsonElement> GetAsync(string staffId, CancellationToken ct = default)
        => Http.GetAsync<JsonElement>($"staff/{staffId}/", cancellationToken: ct);

    /// <summary>Creates a new staff member.</summary>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> CreateAsync(object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("staff/", data, cancellationToken: ct);

    /// <summary>Updates an existing staff member.</summary>
    /// <param name="staffId">The staff member UUID.</param>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> UpdateAsync(string staffId, object data, CancellationToken ct = default)
        => await Http.PutAsync<JsonElement>($"staff/{staffId}/", data, ct);

    /// <summary>Toggles the active/inactive status of a staff member.</summary>
    /// <param name="staffId">The staff member UUID.</param>
    public Task ToggleActiveAsync(string staffId, CancellationToken ct = default)
        => Http.PostAsync($"staff/{staffId}/toggle_active/", cancellationToken: ct);
}
