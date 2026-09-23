using System.Net;
using System.Net.Http.Json;
using EnrolHQ.SDK.Exceptions;
using EnrolHQ.SDK.Models;

namespace EnrolHQ.SDK.Authentication;

/// <summary>
/// DelegatingHandler that manages EnrolHQ token authentication.
/// Uses a long-lived API token to obtain short-lived access tokens
/// via the /accounts/refresh/ endpoint. Automatically refreshes on 401.
/// <para>
/// The refresh request runs on its own <see cref="HttpClient"/> and is bounded
/// by <see cref="RefreshTimeout"/> (the configured client timeout, default
/// 30 s). Previously it used the .NET default of 100 s regardless of the
/// client timeout.
/// </para>
/// </summary>
public sealed class TokenAuthHandler : DelegatingHandler
{
    private readonly string _baseUrl;
    private readonly string _apiToken;
    private string? _accessToken;
    private long _tokenVersion;
    private readonly SemaphoreSlim _refreshLock = new(1, 1);
    private HttpClient? _refreshClient;

    /// <summary>Default timeout for the token-refresh request when none is given.</summary>
    public static readonly TimeSpan DefaultRefreshTimeout = TimeSpan.FromSeconds(30);

    /// <summary>Timeout applied to the token-refresh request.</summary>
    public TimeSpan RefreshTimeout { get; }

    // The two original constructors are kept as real overloads (not optional
    // parameters) so assemblies compiled against 1.1.0 still bind at runtime.
    public TokenAuthHandler(string baseUrl, string apiToken)
        : this(baseUrl, apiToken, DefaultRefreshTimeout)
    {
    }

    public TokenAuthHandler(string baseUrl, string apiToken, TimeSpan timeout)
        : base(new HttpClientHandler())
    {
        _baseUrl = baseUrl.TrimEnd('/') + "/";
        _apiToken = apiToken;
        RefreshTimeout = timeout;
    }

    public TokenAuthHandler(string baseUrl, string apiToken, HttpMessageHandler innerHandler)
        : this(baseUrl, apiToken, innerHandler, DefaultRefreshTimeout)
    {
    }

    public TokenAuthHandler(string baseUrl, string apiToken, HttpMessageHandler innerHandler, TimeSpan timeout)
        : base(innerHandler)
    {
        _baseUrl = baseUrl.TrimEnd('/') + "/";
        _apiToken = apiToken;
        RefreshTimeout = timeout;
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        if (_accessToken is null)
            await RefreshTokenAsync(cancellationToken).ConfigureAwait(false);

        var versionBefore = Volatile.Read(ref _tokenVersion);
        SetAuthHeader(request);
        var response = await base.SendAsync(request, cancellationToken).ConfigureAwait(false);

        if (response.StatusCode == HttpStatusCode.Unauthorized)
        {
            response.Dispose();
            await RefreshTokenAsync(cancellationToken, versionBefore).ConfigureAwait(false);
            SetAuthHeader(request);
            response = await base.SendAsync(request, cancellationToken).ConfigureAwait(false);
        }

        return response;
    }

    private void SetAuthHeader(HttpRequestMessage request)
    {
        request.Headers.Remove("Authorization");
        request.Headers.TryAddWithoutValidation("Authorization", $"Token {_accessToken}");
    }

    private async Task RefreshTokenAsync(CancellationToken cancellationToken, long expectedVersion = -1)
    {
        await _refreshLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            // Skip refresh if another thread already refreshed since we observed the 401
            if (expectedVersion >= 0 && Volatile.Read(ref _tokenVersion) != expectedVersion)
                return;

            _refreshClient ??= new HttpClient(new HttpClientHandler(), disposeHandler: true)
            {
                Timeout = RefreshTimeout,
            };
            var refreshUrl = $"{_baseUrl}accounts/refresh/";

            using var request = new HttpRequestMessage(HttpMethod.Post, refreshUrl);
            request.Headers.TryAddWithoutValidation("Authorization", $"Token {_apiToken}");

            var response = await _refreshClient.SendAsync(request, cancellationToken).ConfigureAwait(false);

            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
                throw new AuthenticationException($"Token refresh failed (HTTP {(int)response.StatusCode})", body);
            }

            var result = await response.Content.ReadFromJsonAsync<TokenRefreshResponse>(
                cancellationToken: cancellationToken).ConfigureAwait(false);

            _accessToken = result?.AccessToken
                ?? throw new AuthenticationException("'access_token' not found in refresh response");

            Interlocked.Increment(ref _tokenVersion);
        }
        finally
        {
            _refreshLock.Release();
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _refreshLock.Dispose();
            _refreshClient?.Dispose();
        }
        base.Dispose(disposing);
    }
}
