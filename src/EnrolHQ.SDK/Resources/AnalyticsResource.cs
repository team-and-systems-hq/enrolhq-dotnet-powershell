using System.Text.Json;
using EnrolHQ.SDK.Http;

namespace EnrolHQ.SDK.Resources;

/// <summary>Analytics and reporting endpoints.</summary>
public class AnalyticsResource : BaseResource
{
    public AnalyticsResource(EnrolHQHttpClient http) : base(http) { }

    public Task<JsonElement> StatisticsAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("application-statistics/", queryParams, ct);

    public Task<JsonElement> ConversionAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("conversion/", queryParams, ct);

    public Task<JsonElement> StatusConversionAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("application-status-conversion/", queryParams, ct);

    public Task<JsonElement> ApplicationsChartAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("charts/applications-chart/", queryParams, ct);

    public Task<JsonElement> CurrentSchoolsChartAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("charts/current-schools-chart/", queryParams, ct);

    public Task<JsonElement> HowHearChartAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("charts/how-hear-chart/", queryParams, ct);

    public Task<JsonElement> MonthlyChartAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("charts/monthly-chart/", queryParams, ct);

    public Task<JsonElement> SuburbsChartAsync(Dictionary<string, string?>? queryParams = null,
        CancellationToken ct = default)
        => Http.GetAsync<JsonElement>("charts/suburbs-chart/", queryParams, ct);
}
