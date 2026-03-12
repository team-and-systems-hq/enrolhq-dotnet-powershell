using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Resources;

namespace EnrolHQ.SDK;

/// <summary>
/// Main client for the EnrolHQ API.
/// <para>
/// Usage:
/// <code>
/// using var client = new EnrolHQClient("enrol.cranbrook.nsw.edu.au", "your_api_token");
/// var apps = await client.Applications.ListAllAsync();
/// </code>
/// </para>
/// </summary>
public sealed class EnrolHQClient : IDisposable
{
    private readonly EnrolHQHttpClient _http;
    private bool _disposed;

    public ApplicationsResource Applications { get; }
    public DocumentsResource Documents { get; }
    public NotesResource Notes { get; }
    public ActivityLogResource ActivityLog { get; }
    public EmailLogResource EmailLog { get; }
    public EventsResource Events { get; }
    public EventBookingsResource EventBookings { get; }
    public PaymentsResource Payments { get; }
    public StaffResource Staff { get; }
    public AnalyticsResource Analytics { get; }
    public ReferenceDataResource ReferenceData { get; }

    /// <summary>The resolved API base URL.</summary>
    public string BaseUrl { get; }

    /// <summary>
    /// Create a client using your EnrolHQ domain
    /// (e.g. "enrol.cranbrook.nsw.edu.au" or "demo.enrolhq.com.au").
    /// </summary>
    public EnrolHQClient(string domain, string apiToken, TimeSpan? timeout = null, int maxRetries = 3)
        : this($"https://{domain}/api/v2/", apiToken, timeout, maxRetries, isBaseUrl: true)
    {
    }

    private EnrolHQClient(string baseUrl, string apiToken, TimeSpan? timeout, int maxRetries, bool isBaseUrl)
    {
        BaseUrl = baseUrl.TrimEnd('/') + "/";
        _http = new EnrolHQHttpClient(BaseUrl, apiToken, timeout, maxRetries);
        Applications = new ApplicationsResource(_http);
        Documents = new DocumentsResource(_http);
        Notes = new NotesResource(_http);
        ActivityLog = new ActivityLogResource(_http);
        EmailLog = new EmailLogResource(_http);
        Events = new EventsResource(_http);
        EventBookings = new EventBookingsResource(_http);
        Payments = new PaymentsResource(_http);
        Staff = new StaffResource(_http);
        Analytics = new AnalyticsResource(_http);
        ReferenceData = new ReferenceDataResource(_http);
    }

    /// <summary>Create a client using a full base URL.</summary>
    public static EnrolHQClient FromBaseUrl(string baseUrl, string apiToken,
        TimeSpan? timeout = null, int maxRetries = 3)
        => new(baseUrl, apiToken, timeout, maxRetries, isBaseUrl: true);

    /// <summary>Create a client from environment variables.</summary>
    /// <remarks>
    /// Reads ENROLHQ_BASE_URL or ENROLHQ_INSTANCE and ENROLHQ_API_TOKEN.
    /// </remarks>
    public static EnrolHQClient FromEnvironment(TimeSpan? timeout = null, int maxRetries = 3)
    {
        var apiToken = Environment.GetEnvironmentVariable("ENROLHQ_API_TOKEN")
            ?? throw new InvalidOperationException("ENROLHQ_API_TOKEN environment variable is required");

        var baseUrl = Environment.GetEnvironmentVariable("ENROLHQ_BASE_URL");
        if (!string.IsNullOrEmpty(baseUrl))
            return FromBaseUrl(baseUrl, apiToken, timeout, maxRetries);

        var domain = Environment.GetEnvironmentVariable("ENROLHQ_INSTANCE")
            ?? throw new InvalidOperationException(
                "Either ENROLHQ_BASE_URL or ENROLHQ_INSTANCE environment variable is required");

        return new EnrolHQClient(domain, apiToken, timeout, maxRetries);
    }

    public override string ToString() => $"EnrolHQClient(BaseUrl={BaseUrl})";

    public void Dispose()
    {
        if (!_disposed)
        {
            _http.Dispose();
            _disposed = true;
        }
    }
}
