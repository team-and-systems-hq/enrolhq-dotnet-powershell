using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>CRUD operations on staff events.</summary>
public class EventsResource : BaseResource
{
    public EventsResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Returns a single page of staff events.</summary>
    public Task<PaginatedResponse<StaffEvent>> ListPageAsync(
        Dictionary<string, string?>? filters = null, int page = 1, int pageSize = 100,
        CancellationToken ct = default)
        => ListPageAsync<StaffEvent>("staff-events/", filters, page, pageSize, ct);

    /// <summary>Returns all staff events, automatically paginating through every page.</summary>
    public Task<List<StaffEvent>> ListAllAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<StaffEvent>("staff-events/", filters, pageSize, ct);

    /// <summary>Retrieves a single staff event by its identifier.</summary>
    /// <param name="eventId">The event UUID.</param>
    public Task<JsonElement> GetAsync(string eventId, CancellationToken ct = default)
        => Http.GetAsync<JsonElement>($"staff-events/{eventId}/", cancellationToken: ct);

    /// <summary>Creates a new staff event.</summary>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> CreateAsync(object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("staff-events/", data, cancellationToken: ct);

    /// <summary>Updates an existing staff event.</summary>
    /// <param name="eventId">The event UUID.</param>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> UpdateAsync(string eventId, object data, CancellationToken ct = default)
        => await Http.PutAsync<JsonElement>($"staff-events/{eventId}/", data, ct);

    /// <summary>Deletes a staff event.</summary>
    /// <param name="eventId">The event UUID.</param>
    public Task DeleteAsync(string eventId, CancellationToken ct = default)
        => Http.DeleteAsync($"staff-events/{eventId}/", ct);
}
