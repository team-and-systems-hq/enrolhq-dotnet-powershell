namespace EnrolHQ.SDK.Exceptions;

/// <summary>Base exception for all EnrolHQ SDK errors.</summary>
public class EnrolHQException : Exception
{
    public EnrolHQException(string message) : base(message) { }
    public EnrolHQException(string message, Exception inner) : base(message, inner) { }
}

/// <summary>Raised for non-success HTTP responses.</summary>
public class ApiException : EnrolHQException
{
    public int StatusCode { get; }
    public object? Detail { get; }
    public string? ResponseBody { get; }

    public ApiException(int statusCode, object? detail = null, string? responseBody = null)
        : base($"HTTP {statusCode}{(detail is not null ? $": {detail}" : "")}")
    {
        StatusCode = statusCode;
        Detail = detail;
        ResponseBody = responseBody;
    }
}

/// <summary>401 Unauthorized — token invalid or expired.</summary>
public class AuthenticationException : ApiException
{
    public AuthenticationException(object? detail = null, string? responseBody = null)
        : base(401, detail ?? "Authentication failed", responseBody) { }
}

/// <summary>400 Bad Request — validation errors.</summary>
public class ValidationException : ApiException
{
    public ValidationException(object? detail = null, string? responseBody = null)
        : base(400, detail ?? "Validation failed", responseBody) { }
}

/// <summary>403 Forbidden — insufficient permissions.</summary>
public class ForbiddenException : ApiException
{
    public ForbiddenException(object? detail = null, string? responseBody = null)
        : base(403, detail ?? "Forbidden", responseBody) { }
}

/// <summary>404 Not Found.</summary>
public class NotFoundException : ApiException
{
    public NotFoundException(object? detail = null, string? responseBody = null)
        : base(404, detail ?? "Not found", responseBody) { }
}

/// <summary>429 Too Many Requests — rate limited.</summary>
public class RateLimitException : ApiException
{
    public int? RetryAfterSeconds { get; }

    public RateLimitException(object? detail = null, string? responseBody = null, int? retryAfter = null)
        : base(429, detail ?? "Rate limit exceeded", responseBody)
    {
        RetryAfterSeconds = retryAfter;
    }
}
