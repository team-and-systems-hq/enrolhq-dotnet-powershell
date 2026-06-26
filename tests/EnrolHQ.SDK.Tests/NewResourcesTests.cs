using System.Net;
using System.Text;
using System.Text.Json;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Resources;
using FluentAssertions;
using Moq;
using Moq.Protected;

namespace EnrolHQ.SDK.Tests;

/// <summary>
/// Tests for the v1.1.0 additions: cursor pagination, the audit log, CMS
/// settings, metafields, application-status-settings, and the bulk
/// change-status repeated-id fix.
/// </summary>
public class NewResourcesTests
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

    private static HttpResponseMessage Json(string body)
        => new(HttpStatusCode.OK) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    #region Cursor pagination

    [Fact]
    public async Task GetAllCursorPagesAsync_Should_Follow_Next_Cursor_Links()
    {
        var requestedUrls = new List<string>();
        var (client, _) = CreateClient((req, _) =>
        {
            var url = req.RequestUri!.ToString();
            requestedUrls.Add(url);
            // First request carries no cursor; return a `next` link.
            if (!url.Contains("cursor="))
            {
                return Task.FromResult(Json($$"""
                {
                    "next": "{{BaseUrl}}audit/log/?cursor=PAGE2&page_size=25",
                    "previous": null,
                    "results": [{ "updated_at": "t1", "changes": ["change 1"] }]
                }
                """));
            }
            // Cursor page: terminate.
            return Task.FromResult(Json("""
            {
                "next": null,
                "previous": "https://x/audit/log/?cursor=PAGE1",
                "results": [{ "updated_at": "t2", "changes": ["change 2"] }]
            }
            """));
        });

        var results = await client.GetAllCursorPagesAsync<JsonElement>("audit/log/",
            new Dictionary<string, string?> { ["student_profile"] = "SP1" }, pageSize: 25);

        results.Should().HaveCount(2);
        results[0].GetProperty("updated_at").GetString().Should().Be("t1");
        results[1].GetProperty("updated_at").GetString().Should().Be("t2");

        requestedUrls.Should().HaveCount(2);
        requestedUrls[0].Should().Contain("student_profile=SP1").And.Contain("page_size=25");
        requestedUrls[0].Should().NotContain("cursor=");
        requestedUrls[1].Should().Contain("cursor=PAGE2");
    }

    #endregion

    #region Audit log

    [Fact]
    public async Task AuditLog_ListByStudentProfile_Should_Filter_By_Student_Profile()
    {
        string? requestedUrl = null;
        var (client, _) = CreateClient((req, _) =>
        {
            requestedUrl = req.RequestUri!.ToString();
            return Task.FromResult(Json("""{ "next": null, "previous": null, "results": [] }"""));
        });

        await new AuditLogResource(client).ListByStudentProfileAsync("SP1");

        requestedUrl.Should().NotBeNull();
        requestedUrl!.Should().Contain("audit/log/").And.Contain("student_profile=SP1");
    }

    [Fact]
    public async Task AuditLog_ListByParent_Should_Filter_By_Parent()
    {
        string? requestedUrl = null;
        var (client, _) = CreateClient((req, _) =>
        {
            requestedUrl = req.RequestUri!.ToString();
            return Task.FromResult(Json("""{ "next": null, "previous": null, "results": [] }"""));
        });

        await new AuditLogResource(client).ListByParentAsync("PAR1");

        requestedUrl!.Should().Contain("audit/log/").And.Contain("parent=PAR1");
    }

    #endregion

    #region CMS settings & metafields

    [Fact]
    public async Task CmsSettings_GetAsync_Should_Call_Cms_Settings_Endpoint()
    {
        string? requestedUrl = null;
        var (client, _) = CreateClient((req, _) =>
        {
            requestedUrl = req.RequestUri!.ToString();
            return Task.FromResult(Json("""{ "parent_label": "Parent" }"""));
        });

        var result = await new CmsSettingsResource(client).GetAsync();

        requestedUrl!.Should().Contain("cms-settings/");
        result.GetProperty("parent_label").GetString().Should().Be("Parent");
    }

    [Fact]
    public async Task Metafields_FieldSettings_Should_Return_Only_Field_Settings()
    {
        var (client, _) = CreateClient((_, _) => Task.FromResult(Json("""
        {
            "field_settings": { "parent": { "first_name": { "label": "First name" } } },
            "default_field_settings": { "parent": { "first_name": { "label": "Default" } } }
        }
        """)));

        var resource = new MetafieldsResource(client);

        var fieldSettings = await resource.FieldSettingsAsync();
        fieldSettings.GetProperty("parent").GetProperty("first_name").GetProperty("label")
            .GetString().Should().Be("First name");

        var defaults = await resource.DefaultFieldSettingsAsync();
        defaults.GetProperty("parent").GetProperty("first_name").GetProperty("label")
            .GetString().Should().Be("Default");
    }

    #endregion

    #region Reference data — application status settings

    [Fact]
    public async Task ReferenceData_ApplicationStatusSettings_Should_Call_Endpoint()
    {
        string? requestedUrl = null;
        var (client, _) = CreateClient((req, _) =>
        {
            requestedUrl = req.RequestUri!.ToString();
            return Task.FromResult(Json("""
            { "count": 1, "next": null, "previous": null,
              "results": [{ "application_status": 4, "status_label": "Enrolment" }] }
            """));
        });

        var result = await new ReferenceDataResource(client).ApplicationStatusSettingsAsync();

        requestedUrl!.Should().Contain("application-status-settings/");
        result.Should().HaveCount(1);
        result[0].GetProperty("status_label").GetString().Should().Be("Enrolment");
    }

    #endregion

    #region Change status — repeated id params

    [Fact]
    public async Task ChangeStatusAsync_Should_Use_Repeated_Id_Params_Not_IdIn()
    {
        HttpRequestMessage? captured = null;
        var (client, _) = CreateClient((req, _) =>
        {
            captured = req;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{}", Encoding.UTF8, "application/json")
            });
        });

        await new ApplicationsResource(client).ChangeStatusAsync(new[] { "uuid1", "uuid2" }, 4);

        captured.Should().NotBeNull();
        captured!.Method.Should().Be(HttpMethod.Post);

        var url = captured.RequestUri!.ToString();
        url.Should().Contain("applications-list/change_status/");
        url.Should().Contain("id=uuid1").And.Contain("id=uuid2");
        url.Should().NotContain("id__in");

        var body = await captured.Content!.ReadAsStringAsync();
        body.Should().Contain("application_status").And.Contain("4");
    }

    #endregion
}
