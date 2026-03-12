using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Web;
using EnrolHQ.SDK.Authentication;
using EnrolHQ.SDK.Exceptions;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Http;

/// <summary>
/// Core HTTP client for EnrolHQ API communication.
/// Handles serialization, error mapping, and pagination.
/// </summary>
public sealed class EnrolHQHttpClient : IDisposable
{
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;
    private bool _disposed;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull,
    };

    public EnrolHQHttpClient(string baseUrl, string apiToken, TimeSpan? timeout = null, int maxRetries = 3)
    {
        _baseUrl = baseUrl.TrimEnd('/') + "/";

        var authHandler = new TokenAuthHandler(_baseUrl, apiToken);
        var retryHandler = new RetryHandler(authHandler, maxRetries);

        _httpClient = new HttpClient(retryHandler, disposeHandler: true)
        {
            Timeout = timeout ?? TimeSpan.FromSeconds(30),
        };
    }

    /// <summary>For testing — inject a pre-configured HttpClient.</summary>
    internal EnrolHQHttpClient(string baseUrl, HttpClient httpClient)
    {
        _baseUrl = baseUrl.TrimEnd('/') + "/";
        _httpClient = httpClient;
    }

    public string BuildUrl(string endpoint) => _baseUrl + endpoint.TrimStart('/');

    public string BuildUrl(string endpoint, Dictionary<string, string?>? queryParams)
    {
        var url = BuildUrl(endpoint);
        if (queryParams is null || queryParams.Count == 0)
            return url;

        var query = HttpUtility.ParseQueryString(string.Empty);
        foreach (var (key, value) in queryParams)
        {
            if (value is not null)
                query[key] = value;
        }

        return $"{url}?{query}";
    }

    public async Task<T> GetAsync<T>(string endpoint, Dictionary<string, string?>? queryParams = null,
        CancellationToken cancellationToken = default)
    {
        var url = BuildUrl(endpoint, queryParams);
        var response = await _httpClient.GetAsync(url, cancellationToken).ConfigureAwait(false);
        await EnsureSuccessAsync(response, cancellationToken).ConfigureAwait(false);
        return (await response.Content.ReadFromJsonAsync<T>(JsonOptions, cancellationToken)
            .ConfigureAwait(false))!;
    }

    public async Task<HttpResponseMessage> GetRawAsync(string url, CancellationToken cancellationToken = default)
    {
        var response = await _httpClient.GetAsync(url, cancellationToken).ConfigureAwait(false);
        await EnsureSuccessAsync(response, cancellationToken).ConfigureAwait(false);
        return response;
    }

    public async Task<T?> PostAsync<T>(string endpoint, object? body = null,
        Dictionary<string, string?>? queryParams = null, CancellationToken cancellationToken = default)
    {
        var url = BuildUrl(endpoint, queryParams);
        var content = SerializeBody(body);
        var response = await _httpClient.PostAsync(url, content, cancellationToken).ConfigureAwait(false);
        await EnsureSuccessAsync(response, cancellationToken).ConfigureAwait(false);

        if (IsEmptyResponse(response))
            return default;

        return await response.Content.ReadFromJsonAsync<T>(JsonOptions, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task PostAsync(string endpoint, object? body = null,
        Dictionary<string, string?>? queryParams = null, CancellationToken cancellationToken = default)
    {
        var url = BuildUrl(endpoint, queryParams);
        var content = SerializeBody(body);
        var response = await _httpClient.PostAsync(url, content, cancellationToken).ConfigureAwait(false);
        await EnsureSuccessAsync(response, cancellationToken).ConfigureAwait(false);
    }

    public async Task<T?> PostMultipartAsync<T>(string endpoint, MultipartFormDataContent content,
        CancellationToken cancellationToken = default)
    {
        var url = BuildUrl(endpoint);
        var response = await _httpClient.PostAsync(url, content, cancellationToken).ConfigureAwait(false);
        await EnsureSuccessAsync(response, cancellationToken).ConfigureAwait(false);
        return await response.Content.ReadFromJsonAsync<T>(JsonOptions, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<T?> PutAsync<T>(string endpoint, object? body = null,
        CancellationToken cancellationToken = default)
    {
        var url = BuildUrl(endpoint);
        var content = SerializeBody(body);
        var response = await _httpClient.PutAsync(url, content, cancellationToken).ConfigureAwait(false);
        await EnsureSuccessAsync(response, cancellationToken).ConfigureAwait(false);

        if (IsEmptyResponse(response))
            return default;

        return await response.Content.ReadFromJsonAsync<T>(JsonOptions, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<T?> PatchAsync<T>(string endpoint, object? body = null,
        CancellationToken cancellationToken = default)
    {
        var url = BuildUrl(endpoint);
        var content = SerializeBody(body);
        var response = await _httpClient.PatchAsync(url, content, cancellationToken)
            .ConfigureAwait(false);
        await EnsureSuccessAsync(response, cancellationToken).ConfigureAwait(false);

        if (IsEmptyResponse(response))
            return default;

        return await response.Content.ReadFromJsonAsync<T>(JsonOptions, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task DeleteAsync(string endpoint, CancellationToken cancellationToken = default)
    {
        var url = BuildUrl(endpoint);
        var response = await _httpClient.DeleteAsync(url, cancellationToken).ConfigureAwait(false);
        await EnsureSuccessAsync(response, cancellationToken).ConfigureAwait(false);
    }

    public async Task<PaginatedResponse<T>> GetPageAsync<T>(string endpoint,
        Dictionary<string, string?>? queryParams = null, int page = 1, int pageSize = 100,
        CancellationToken cancellationToken = default)
    {
        var allParams = new Dictionary<string, string?>(queryParams ?? [])
        {
            ["page"] = page.ToString(),
            ["page_size"] = pageSize.ToString(),
        };
        return await GetAsync<PaginatedResponse<T>>(endpoint, allParams, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<List<T>> GetAllPagesAsync<T>(string endpoint,
        Dictionary<string, string?>? queryParams = null, int pageSize = 100, int maxPages = 10000,
        CancellationToken cancellationToken = default)
    {
        var results = new List<T>();
        for (int page = 1; page <= maxPages; page++)
        {
            var response = await GetPageAsync<T>(endpoint, queryParams, page, pageSize, cancellationToken)
                .ConfigureAwait(false);
            results.AddRange(response.Results);
            if (!response.HasNext)
                break;
        }
        return results;
    }

    private static StringContent? SerializeBody(object? body)
        => body is not null
            ? new StringContent(JsonSerializer.Serialize(body, JsonOptions), Encoding.UTF8, "application/json")
            : null;

    private static bool IsEmptyResponse(HttpResponseMessage response)
        => response.StatusCode == HttpStatusCode.NoContent
            || response.Content.Headers.ContentLength is 0;

    private static async Task EnsureSuccessAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        if (response.IsSuccessStatusCode)
            return;

        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        object? detail = null;

        try
        {
            var json = JsonSerializer.Deserialize<JsonElement>(body);
            if (json.TryGetProperty("detail", out var detailProp))
                detail = detailProp.ToString();
            else
                detail = body;
        }
        catch
        {
            detail = body;
        }

        throw response.StatusCode switch
        {
            HttpStatusCode.BadRequest => new ValidationException(detail, body),
            HttpStatusCode.Unauthorized => new AuthenticationException(detail, body),
            HttpStatusCode.Forbidden => new ForbiddenException(detail, body),
            HttpStatusCode.NotFound => new NotFoundException(detail, body),
            HttpStatusCode.TooManyRequests => new RateLimitException(detail, body,
                response.Headers.TryGetValues("Retry-After", out var vals)
                && int.TryParse(vals.FirstOrDefault(), out var secs) ? secs : null),
            _ => new ApiException((int)response.StatusCode, detail, body),
        };
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            _httpClient.Dispose();
            _disposed = true;
        }
    }
}
