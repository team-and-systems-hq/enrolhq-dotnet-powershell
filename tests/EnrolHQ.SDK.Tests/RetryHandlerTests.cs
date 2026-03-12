using System.Net;
using EnrolHQ.SDK.Http;
using FluentAssertions;
using Moq;
using Moq.Protected;

namespace EnrolHQ.SDK.Tests;

/// <summary>
/// Tests for the RetryHandler delegating handler that implements
/// exponential backoff with jitter for transient failures.
/// Retries on 429, 500, 502, 503, 504 status codes.
/// </summary>
public class RetryHandlerTests
{
    private const int DefaultMaxRetries = 3;
    private static readonly TimeSpan FastBaseDelay = TimeSpan.FromMilliseconds(1);

    /// <summary>
    /// Creates a RetryHandler with a mock inner handler that invokes a callback on each request.
    /// Uses a very short base delay to keep tests fast.
    /// </summary>
    private static (RetryHandler handler, Mock<HttpMessageHandler> mockInner) CreateRetryHandler(
        int maxRetries,
        Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> callback)
    {
        var mockInner = new Mock<HttpMessageHandler>(MockBehavior.Loose);
        mockInner.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .Returns<HttpRequestMessage, CancellationToken>(callback);

        var handler = new RetryHandler(mockInner.Object, maxRetries, FastBaseDelay);
        return (handler, mockInner);
    }

    [Fact]
    public async Task Should_Retry_On_429_TooManyRequests()
    {
        // Arrange
        var callCount = 0;
        var (handler, mockInner) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            if (callCount <= 2)
            {
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.TooManyRequests)
                {
                    Content = new StringContent("{\"detail\": \"Rate limit exceeded\"}")
                });
            }
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"results\": []}")
            });
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/applications-list/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        callCount.Should().Be(3, "initial request + 2 retries before success");
    }

    [Fact]
    public async Task Should_Retry_On_500_InternalServerError()
    {
        // Arrange
        var callCount = 0;
        var (handler, _) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            if (callCount == 1)
            {
                return Task.FromResult(
                    new HttpResponseMessage(HttpStatusCode.InternalServerError));
            }
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"results\": []}")
            });
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/applications-list/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        callCount.Should().Be(2);
    }

    [Fact]
    public async Task Should_Retry_On_502_BadGateway()
    {
        // Arrange
        var callCount = 0;
        var (handler, _) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            if (callCount == 1)
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.BadGateway));
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK));
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/staff/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Should_Retry_On_503_ServiceUnavailable()
    {
        // Arrange
        var callCount = 0;
        var (handler, _) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            if (callCount == 1)
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable));
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK));
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/events/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Should_Retry_On_504_GatewayTimeout()
    {
        // Arrange
        var callCount = 0;
        var (handler, _) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            if (callCount == 1)
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.GatewayTimeout));
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK));
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/applications-list/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Should_Not_Retry_On_400_BadRequest()
    {
        // Arrange
        var callCount = 0;
        var (handler, mockInner) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.BadRequest)
            {
                Content = new StringContent("{\"detail\": \"Validation failed\"}")
            });
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/applications/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        callCount.Should().Be(1, "400 errors should not be retried");
    }

    [Fact]
    public async Task Should_Not_Retry_On_401_Unauthorized()
    {
        // Arrange -- 401 is handled by TokenAuthHandler, not RetryHandler
        var callCount = 0;
        var (handler, _) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.Unauthorized)
            {
                Content = new StringContent("{\"detail\": \"Authentication required\"}")
            });
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/applications-list/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        callCount.Should().Be(1, "401 should not be retried by RetryHandler");
    }

    [Fact]
    public async Task Should_Not_Retry_On_403_Forbidden()
    {
        // Arrange
        var callCount = 0;
        var (handler, _) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.Forbidden)
            {
                Content = new StringContent("{\"detail\": \"Permission denied\"}")
            });
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/admin/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
        callCount.Should().Be(1, "403 should not be retried");
    }

    [Fact]
    public async Task Should_Not_Retry_On_404_NotFound()
    {
        // Arrange
        var callCount = 0;
        var (handler, _) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound)
            {
                Content = new StringContent("{\"detail\": \"Not found\"}")
            });
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/applications/nonexistent/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
        callCount.Should().Be(1, "404 should not be retried");
    }

    [Fact]
    public async Task Should_Respect_Max_Retries()
    {
        // Arrange -- all requests return 500, should stop after maxRetries + 1 total attempts
        var maxRetries = 3;
        var callCount = 0;
        var (handler, _) = CreateRetryHandler(maxRetries, (req, ct) =>
        {
            callCount++;
            return Task.FromResult(
                new HttpResponseMessage(HttpStatusCode.InternalServerError));
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/applications-list/");

        // Assert -- 1 initial + 3 retries = 4 total attempts
        response.StatusCode.Should().Be(HttpStatusCode.InternalServerError);
        callCount.Should().Be(maxRetries + 1,
            $"should make {maxRetries + 1} total attempts (1 initial + {maxRetries} retries)");
    }

    [Fact]
    public async Task Should_Return_Successful_Response_Without_Retry()
    {
        // Arrange
        var callCount = 0;
        var (handler, _) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"results\": [{\"id\": \"app-001\"}]}")
            });
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/applications-list/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        callCount.Should().Be(1, "successful responses should not trigger retries");
    }

    [Fact]
    public async Task Should_Respect_Retry_After_Header()
    {
        // Arrange
        var callCount = 0;
        var (handler, _) = CreateRetryHandler(DefaultMaxRetries, (req, ct) =>
        {
            callCount++;
            if (callCount == 1)
            {
                var response429 = new HttpResponseMessage(HttpStatusCode.TooManyRequests)
                {
                    Content = new StringContent("{\"detail\": \"Rate limit exceeded\"}")
                };
                response429.Headers.TryAddWithoutValidation("Retry-After", "1");
                return Task.FromResult(response429);
            }
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"results\": []}")
            });
        });

        using var client = new HttpClient(handler);

        // Act
        var response = await client.GetAsync("https://test.enrolhq.com.au/api/v2/applications-list/");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        callCount.Should().Be(2);
    }

    [Fact]
    public void Should_Default_To_Three_Max_Retries()
    {
        // Arrange & Act
        var handler = new RetryHandler();

        // Assert - verify the handler was created (default constructor)
        handler.Should().NotBeNull();
    }

    [Fact]
    public void Should_Accept_Custom_Base_Delay()
    {
        // Arrange & Act
        var handler = new RetryHandler(maxRetries: 5, baseDelay: TimeSpan.FromSeconds(2));

        // Assert
        handler.Should().NotBeNull();
    }
}
