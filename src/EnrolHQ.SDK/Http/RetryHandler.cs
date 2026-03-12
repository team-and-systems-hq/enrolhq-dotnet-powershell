using System.Net;

namespace EnrolHQ.SDK.Http;

/// <summary>
/// DelegatingHandler implementing exponential backoff with jitter for transient failures.
/// Retries on 429 (rate limit), 500, 502, 503, 504.
/// </summary>
public sealed class RetryHandler : DelegatingHandler
{
    private static readonly HashSet<HttpStatusCode> RetryableStatusCodes =
    [
        HttpStatusCode.TooManyRequests,          // 429
        HttpStatusCode.InternalServerError,      // 500
        HttpStatusCode.BadGateway,               // 502
        HttpStatusCode.ServiceUnavailable,       // 503
        HttpStatusCode.GatewayTimeout,           // 504
    ];

    private readonly int _maxRetries;
    private readonly TimeSpan _baseDelay;

    public RetryHandler(int maxRetries = 3, TimeSpan? baseDelay = null)
        : base()
    {
        _maxRetries = maxRetries;
        _baseDelay = baseDelay ?? TimeSpan.FromSeconds(1);
    }

    public RetryHandler(HttpMessageHandler innerHandler, int maxRetries = 3, TimeSpan? baseDelay = null)
        : base(innerHandler)
    {
        _maxRetries = maxRetries;
        _baseDelay = baseDelay ?? TimeSpan.FromSeconds(1);
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        HttpResponseMessage? response = null;

        for (int attempt = 0; attempt <= _maxRetries; attempt++)
        {
            if (attempt > 0)
            {
                var delay = CalculateDelay(attempt, response);
                await Task.Delay(delay, cancellationToken).ConfigureAwait(false);
            }

            response = await base.SendAsync(request, cancellationToken).ConfigureAwait(false);

            if (!RetryableStatusCodes.Contains(response.StatusCode))
                return response;

            if (attempt == _maxRetries)
                return response;
        }

        return response!;
    }

    private TimeSpan CalculateDelay(int attempt, HttpResponseMessage? lastResponse)
    {
        // Respect Retry-After header on 429
        if (lastResponse?.StatusCode == HttpStatusCode.TooManyRequests &&
            lastResponse.Headers.TryGetValues("Retry-After", out var values))
        {
            var retryAfter = values.FirstOrDefault();
            if (int.TryParse(retryAfter, out var seconds))
                return TimeSpan.FromSeconds(seconds);
        }

        // Exponential backoff with jitter: baseDelay * 2^(attempt-1) + random jitter
        var exponentialDelay = _baseDelay * Math.Pow(2, attempt - 1);
        var jitter = TimeSpan.FromMilliseconds(Random.Shared.Next(0, 1000));
        return exponentialDelay + jitter;
    }
}
