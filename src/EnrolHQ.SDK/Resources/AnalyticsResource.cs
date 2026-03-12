using System.Text.Json;
using EnrolHQ.SDK.Http;

namespace EnrolHQ.SDK.Resources;

/// <summary>Analytics and reporting endpoints.</summary>
public class AnalyticsResource : BaseResource
{
    public AnalyticsResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Retrieves application statistics (counts by status, campus, etc.).</summary>
    public Task<JsonElement> StatisticsAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("application-statistics/", queryParams, ct);

    /// <summary>Retrieves conversion funnel data.</summary>
    public Task<JsonElement> ConversionAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("conversion/", queryParams, ct);

    /// <summary>Retrieves application status conversion data.</summary>
    public Task<JsonElement> StatusConversionAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("application-status-conversion/", queryParams, ct);

    /// <summary>Retrieves the applications chart data.</summary>
    public Task<JsonElement> ApplicationsChartAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("charts/applications-chart/", queryParams, ct);

    /// <summary>Retrieves the current-schools chart data.</summary>
    public Task<JsonElement> CurrentSchoolsChartAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("charts/current-schools-chart/", queryParams, ct);

    /// <summary>Retrieves the how-did-you-hear-about-us chart data.</summary>
    public Task<JsonElement> HowHearChartAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("charts/how-hear-chart/", queryParams, ct);

    /// <summary>Retrieves the monthly applications chart data.</summary>
    public Task<JsonElement> MonthlyChartAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("charts/monthly-chart/", queryParams, ct);

    /// <summary>Retrieves the suburbs chart data.</summary>
    public Task<JsonElement> SuburbsChartAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("charts/suburbs-chart/", queryParams, ct);
}
