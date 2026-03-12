using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>Manage event bookings (staff-side).</summary>
public class EventBookingsResource : BaseResource
{
    public EventBookingsResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Returns a single page of event bookings.</summary>
    public Task<PaginatedResponse<EventBooking>> ListPageAsync(
        Dictionary<string, string?>? filters = null, int page = 1, int pageSize = 100,
        CancellationToken ct = default)
        => ListPageAsync<EventBooking>("staff-event-bookings/", filters, page, pageSize, ct);

    /// <summary>Returns all event bookings, automatically paginating through every page.</summary>
    public Task<List<EventBooking>> ListAllAsync(
        Dictionary<string, string?>? filters = null, int pageSize = 100, CancellationToken ct = default)
        => ListAllAsync<EventBooking>("staff-event-bookings/", filters, pageSize, ct);

    /// <summary>Creates a new event booking.</summary>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> CreateAsync(object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("staff-event-bookings/", data, cancellationToken: ct);

    /// <summary>Updates an existing event booking.</summary>
    /// <param name="bookingId">The event booking UUID.</param>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> UpdateAsync(string bookingId, object data, CancellationToken ct = default)
        => await Http.PutAsync<JsonElement>($"staff-event-bookings/{bookingId}/", data, ct);

    /// <summary>Retrieves the most recent event booking matching the query parameters.</summary>
    public Task<JsonElement> MostRecentForAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("staff-event-bookings/most_recent_for/", queryParams, ct);
}
