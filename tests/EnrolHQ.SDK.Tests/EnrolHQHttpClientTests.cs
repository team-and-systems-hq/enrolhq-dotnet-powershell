using System.Net;
using System.Text;
using System.Text.Json;
using EnrolHQ.SDK.Exceptions;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;
using FluentAssertions;
using Moq;
using Moq.Protected;

namespace EnrolHQ.SDK.Tests;

/// <summary>
/// Tests for EnrolHQHttpClient covering PatchAsync, empty response handling,
/// URL building, error mapping, and pagination.
/// Uses the internal constructor to inject a mock HttpClient.
/// </summary>
public class EnrolHQHttpClientTests
{
    private const string BaseUrl = "https://testschool.enrolhq.com.au/api/v2/";

    private static (EnrolHQHttpClient client, Mock<HttpMessageHandler> mockHandler) CreateClient(
        Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> callback)
    {
        var mockHandler = new Mock<HttpMessageHandler>(MockBehavior.Loose);
        mockHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .Returns<HttpRequestMessage, CancellationToken>(callback);

        var httpClient = new HttpClient(mockHandler.Object);
        var client = new EnrolHQHttpClient(BaseUrl, httpClient);
        return (client, mockHandler);
    }

    #region URL Building

    [Fact]
    public void BuildUrl_Should_Combine_BaseUrl_And_Endpoint()
    {
        var (client, _) = CreateClient((_, _) => throw new NotImplementedException());
        client.BuildUrl("applications-list/").Should().Be($"{BaseUrl}applications-list/");
    }

    [Fact]
    public void BuildUrl_Should_Handle_Leading_Slash_In_Endpoint()
    {
        var (client, _) = CreateClient((_, _) => throw new NotImplementedException());
        client.BuildUrl("/applications-list/").Should().Be($"{BaseUrl}applications-list/");
    }

    [Fact]
    public void BuildUrl_Should_Append_QueryParams()
    {
        var (client, _) = CreateClient((_, _) => throw new NotImplementedException());
        var url = client.BuildUrl("applications-list/", new Dictionary<string, string?>
        {
            ["entry_year"] = "2026",
            ["page"] = "1"
        });
        url.Should().Contain("entry_year=2026");
        url.Should().Contain("page=1");
    }

    [Fact]
    public void BuildUrl_Should_Skip_Null_QueryParams()
    {
        var (client, _) = CreateClient((_, _) => throw new NotImplementedException());
        var url = client.BuildUrl("applications-list/", new Dictionary<string, string?>
        {
            ["entry_year"] = "2026",
            ["campus"] = null
        });
        url.Should().Contain("entry_year=2026");
        url.Should().NotContain("campus");
    }

    #endregion

    #region PatchAsync

    [Fact]
    public async Task PatchAsync_Should_Send_PATCH_Request_With_Body()
    {
        HttpRequestMessage? capturedRequest = null;
        var (client, _) = CreateClient(async (req, ct) =>
        {
            capturedRequest = req;
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """{"id": "app-001", "first_name": "Alice", "last_name": "Smith", "application_status": 4}""",
                    Encoding.UTF8, "application/json")
            };
        });

        var result = await client.PatchAsync<StudentProfile>("applications/app-001/", new
        {
            first_name = "Alice"
        });

        capturedRequest.Should().NotBeNull();
        capturedRequest!.Method.Should().Be(HttpMethod.Patch);
        result.Should().NotBeNull();
        result!.FirstName.Should().Be("Alice");
    }

    [Fact]
    public async Task PatchAsync_Should_Return_Default_On_204_NoContent()
    {
        var (client, _) = CreateClient(async (req, ct) =>
        {
            return new HttpResponseMessage(HttpStatusCode.NoContent);
        });

        var result = await client.PatchAsync<StudentProfile>("applications/app-001/", new
        {
            is_favorite = true
        });

        result.Should().BeNull();
    }

    [Fact]
    public async Task PatchAsync_Should_Return_Default_On_Empty_ContentLength()
    {
        var (client, _) = CreateClient(async (req, ct) =>
        {
            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("", Encoding.UTF8, "application/json")
            };
            response.Content.Headers.ContentLength = 0;
            return response;
        });

        var result = await client.PatchAsync<StudentProfile>("applications/app-001/");

        result.Should().BeNull();
    }

    [Fact]
    public async Task PatchAsync_Should_Throw_On_400_ValidationError()
    {
        var (client, _) = CreateClient(async (req, ct) =>
        {
            return new HttpResponseMessage(HttpStatusCode.BadRequest)
            {
                Content = new StringContent(
                    """{"detail": "Invalid entry_grade"}""",
                    Encoding.UTF8, "application/json")
            };
        });

        var act = () => client.PatchAsync<StudentProfile>("applications/app-001/", new
        {
            entry_grade = -1
        });

        await act.Should().ThrowAsync<ValidationException>();
    }

    [Fact]
    public async Task PatchAsync_Should_Throw_NotFoundException_On_404()
    {
        var (client, _) = CreateClient(async (req, ct) =>
        {
            return new HttpResponseMessage(HttpStatusCode.NotFound)
            {
                Content = new StringContent(
                    """{"detail": "Not found."}""",
                    Encoding.UTF8, "application/json")
            };
        });

        var act = () => client.PatchAsync<StudentProfile>("applications/nonexistent/", new
        {
            first_name = "Test"
        });

        await act.Should().ThrowAsync<NotFoundException>();
    }

    #endregion

    #region PostAsync — Empty Response

    [Fact]
    public async Task PostAsync_Should_Return_Default_On_204_NoContent()
    {
        var (client, _) = CreateClient(async (req, ct) =>
        {
            return new HttpResponseMessage(HttpStatusCode.NoContent);
        });

        var result = await client.PostAsync<StudentProfile>("applications/app-001/some-action/");

        result.Should().BeNull();
    }

    #endregion

    #region PutAsync — Empty Response

    [Fact]
    public async Task PutAsync_Should_Return_Default_On_204_NoContent()
    {
        var (client, _) = CreateClient(async (req, ct) =>
        {
            return new HttpResponseMessage(HttpStatusCode.NoContent);
        });

        var result = await client.PutAsync<StudentProfile>("applications/app-001/", new
        {
            first_name = "Updated"
        });

        result.Should().BeNull();
    }

    #endregion

    #region GetAsync

    [Fact]
    public async Task GetAsync_Should_Deserialize_Response()
    {
        var (client, _) = CreateClient(async (req, ct) =>
        {
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """{"id": "app-001", "first_name": "Bob", "last_name": "Jones", "application_status": 2}""",
                    Encoding.UTF8, "application/json")
            };
        });

        var result = await client.GetAsync<StudentProfile>("applications/app-001/");

        result.Should().NotBeNull();
        result.Id.Should().Be("app-001");
        result.FirstName.Should().Be("Bob");
    }

    [Fact]
    public async Task GetAsync_Should_Throw_AuthenticationException_On_401()
    {
        var (client, _) = CreateClient(async (req, ct) =>
        {
            return new HttpResponseMessage(HttpStatusCode.Unauthorized)
            {
                Content = new StringContent(
                    """{"detail": "Token expired"}""",
                    Encoding.UTF8, "application/json")
            };
        });

        var act = () => client.GetAsync<StudentProfile>("applications/app-001/");

        await act.Should().ThrowAsync<AuthenticationException>();
    }

    [Fact]
    public async Task GetAsync_Should_Throw_RateLimitException_On_429()
    {
        var (client, _) = CreateClient(async (req, ct) =>
        {
            var response = new HttpResponseMessage(HttpStatusCode.TooManyRequests)
            {
                Content = new StringContent(
                    """{"detail": "Rate limit exceeded"}""",
                    Encoding.UTF8, "application/json")
            };
            response.Headers.TryAddWithoutValidation("Retry-After", "30");
            return response;
        });

        var act = () => client.GetAsync<StudentProfile>("applications-list/");

        var ex = await act.Should().ThrowAsync<RateLimitException>();
        ex.Which.RetryAfterSeconds.Should().Be(30);
    }

    #endregion

    #region DeleteAsync

    [Fact]
    public async Task DeleteAsync_Should_Send_DELETE_Request()
    {
        HttpMethod? capturedMethod = null;
        var (client, _) = CreateClient(async (req, ct) =>
        {
            capturedMethod = req.Method;
            return new HttpResponseMessage(HttpStatusCode.NoContent);
        });

        await client.DeleteAsync("notes/note-001/");

        capturedMethod.Should().Be(HttpMethod.Delete);
    }

    #endregion

    #region Pagination

    [Fact]
    public async Task GetPageAsync_Should_Add_Page_And_PageSize_Params()
    {
        string? capturedUrl = null;
        var (client, _) = CreateClient(async (req, ct) =>
        {
            capturedUrl = req.RequestUri?.ToString();
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """{"count": 0, "next": null, "previous": null, "results": []}""",
                    Encoding.UTF8, "application/json")
            };
        });

        await client.GetPageAsync<StudentProfile>("applications-list/", page: 3, pageSize: 50);

        capturedUrl.Should().Contain("page=3");
        capturedUrl.Should().Contain("page_size=50");
    }

    [Fact]
    public async Task GetAllPagesAsync_Should_Follow_Pagination()
    {
        var callCount = 0;
        var (client, _) = CreateClient(async (req, ct) =>
        {
            callCount++;
            var hasNext = callCount < 3;
            var json = $$"""
            {
                "count": 30,
                "next": {{(hasNext ? $"\"https://testschool.enrolhq.com.au/api/v2/applications-list/?page={callCount + 1}\"" : "null")}},
                "previous": null,
                "results": [
                    {"id": "app-{{callCount}}", "first_name": "Student{{callCount}}", "last_name": "Test", "application_status": 0}
                ]
            }
            """;
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            };
        });

        var results = await client.GetAllPagesAsync<StudentProfile>("applications-list/", pageSize: 10);

        results.Should().HaveCount(3);
        callCount.Should().Be(3);
    }

    #endregion

    #region Dispose

    [Fact]
    public void Dispose_Should_Not_Throw_On_Double_Dispose()
    {
        var (client, _) = CreateClient(async (req, ct) =>
            new HttpResponseMessage(HttpStatusCode.OK));

        client.Dispose();
        var act = () => client.Dispose();

        act.Should().NotThrow();
    }

    #endregion
}
