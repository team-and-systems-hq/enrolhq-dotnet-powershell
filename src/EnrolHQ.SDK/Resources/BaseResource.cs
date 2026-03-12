using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Resources;

/// <summary>Base class for API resource groups.</summary>
public abstract class BaseResource
{
    protected readonly EnrolHQHttpClient Http;

    protected BaseResource(EnrolHQHttpClient http) => Http = http;

    protected Task<PaginatedResponse<T>> ListPageAsync<T>(string endpoint,
        Dictionary<string, string?>? queryParams = null, int page = 1, int pageSize = 100,
        CancellationToken cancellationToken = default)
        => Http.GetPageAsync<T>(endpoint, queryParams, page, pageSize, cancellationToken);

    protected Task<List<T>> ListAllAsync<T>(string endpoint,
        Dictionary<string, string?>? queryParams = null, int pageSize = 100,
        CancellationToken cancellationToken = default)
        => Http.GetAllPagesAsync<T>(endpoint, queryParams, pageSize, cancellationToken: cancellationToken);
}
