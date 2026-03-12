using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>CRUD operations on staff events.</summary>
public class EventsResource : BaseResource
{
    public EventsResource(EnrolHQHttpClient http) : base(http) { }

    public Task<PaginatedResponse<StaffEvent>> ListPageAsync(
        Dictionary<string, string?>? filters = null, int page = 1, int pageSize = 100,
        CancellationToken ct = default)
        => ListPageAsync<StaffEvent>("staff-events/", filters, page, pageSize, ct);

    public Task<List<StaffEvent>> ListAllAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<StaffEvent>("staff-events/", filters, pageSize, ct);

    public Task<JsonElement> GetAsync(string eventId, CancellationToken ct = default)
        => Http.GetAsync<JsonElement>($"staff-events/{eventId}/", cancellationToken: ct);

    public async Task<JsonElement> CreateAsync(object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("staff-events/", data, cancellationToken: ct);

    public async Task<JsonElement> UpdateAsync(string eventId, object data, CancellationToken ct = default)
        => await Http.PutAsync<JsonElement>($"staff-events/{eventId}/", data, ct);

    public Task DeleteAsync(string eventId, CancellationToken ct = default)
        => Http.DeleteAsync($"staff-events/{eventId}/", ct);
}
