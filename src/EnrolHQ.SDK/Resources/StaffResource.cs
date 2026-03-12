using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>Manage staff members.</summary>
public class StaffResource : BaseResource
{
    public StaffResource(EnrolHQHttpClient http) : base(http) { }

    public Task<PaginatedResponse<StaffMember>> ListPageAsync(
        Dictionary<string, string?>? filters = null, int page = 1, int pageSize = 100,
        CancellationToken ct = default)
        => ListPageAsync<StaffMember>("staff/", filters, page, pageSize, ct);

    public Task<List<StaffMember>> ListAllAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<StaffMember>("staff/", filters, pageSize, ct);

    public Task<JsonElement> GetAsync(string staffId, CancellationToken ct = default)
        => Http.GetAsync<JsonElement>($"staff/{staffId}/", cancellationToken: ct);

    public async Task<JsonElement> CreateAsync(object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("staff/", data, cancellationToken: ct);

    public async Task<JsonElement> UpdateAsync(string staffId, object data, CancellationToken ct = default)
        => await Http.PutAsync<JsonElement>($"staff/{staffId}/", data, ct);

    public Task ToggleActiveAsync(string staffId, CancellationToken ct = default)
        => Http.PostAsync($"staff/{staffId}/toggle_active/", cancellationToken: ct);
}
