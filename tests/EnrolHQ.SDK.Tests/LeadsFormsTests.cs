using System.Net;
using System.Text;
using System.Text.Json;
using EnrolHQ.SDK.Exceptions;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;
using EnrolHQ.SDK.Resources;
using FluentAssertions;
using Moq;
using Moq.Protected;

namespace EnrolHQ.SDK.Tests;

/// <summary>
/// Tests for the v1.2.0 additions: leads (with lead references), custom forms
/// and submissions (labelled answers, consents), and the application
/// emergency-contact / medical-data / guardian accessors.
/// </summary>
public class LeadsFormsTests
{
    private const string BaseUrl = "https://testschool.enrolhq.com.au/api/v2/";

    private sealed record Recorded(HttpMethod Method, string Url, string? Body);

    /// <summary>
    /// Creates a client whose handler records every request (method, URL, body)
    /// and answers via <paramref name="respond"/>, which dispatches on method + URL.
    /// </summary>
    private static (EnrolHQHttpClient client, List<Recorded> requests) CreateClient(
        Func<HttpMethod, string, string?, HttpResponseMessage> respond)
    {
        var requests = new List<Recorded>();
        var mockHandler = new Mock<HttpMessageHandler>(MockBehavior.Loose);
        mockHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .Returns<HttpRequestMessage, CancellationToken>(async (req, _) =>
            {
                // Read the body before returning — the request may be disposed afterwards.
                var body = req.Content is null ? null : await req.Content.ReadAsStringAsync();
                var url = req.RequestUri!.ToString();
                requests.Add(new Recorded(req.Method, url, body));
                return respond(req.Method, url, body);
            });

        var client = new EnrolHQHttpClient(BaseUrl, new HttpClient(mockHandler.Object));
        return (client, requests);
    }

    private static HttpResponseMessage Json(string body)
        => new(HttpStatusCode.OK) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    /// <summary>True when the URL's path is exactly /api/v2/{endpoint} (query string ignored).</summary>
    private static bool IsEndpoint(string url, string endpoint)
        => new Uri(url).AbsolutePath == "/api/v2/" + endpoint;

    private static JsonElement Parse(string json) => JsonSerializer.Deserialize<JsonElement>(json);

    private static string Paginated(string resultsJson)
        => $$"""{ "count": 1, "next": null, "previous": null, "results": {{resultsJson}} }""";

    /// <summary>A form submit shaped like the real staff-submits detail response.</summary>
    private static string SubmitJson(string id = "submit-1") => $$"""
        {
            "id": "{{id}}",
            "completed_at": "2026-08-20T09:39:21+10:00",
            "form_schema": {
                "id": "schema-version-1",
                "schema": [
                    {
                        "title": "Emergency Contacts",
                        "elements": [
                            { "name": "intro", "element_type": "HTML", "content": "<p>hi</p>" },
                            { "name": "contacts_of_emergency_1", "element_type": "EMERGENCY_CONTACTS" }
                        ]
                    },
                    {
                        "title": "Photograph/Video Permission Form",
                        "elements": [
                            { "name": "group_3_social_media", "label": "Group 3: Social Media", "element_type": "RADIO", "options": ["Yes", "No"] },
                            { "name": "notes", "label": " Anything else? ", "element_type": "TEXT" }
                        ]
                    }
                ]
            },
            "initial_payload": {
                "contacts_of_emergency_1": [{ "first_name": "Ada" }],
                "group_3_social_media": "",
                "notes": ""
            },
            "payload": { "group_3_social_media": "Yes" }
        }
        """;

    /// <summary>A school settings payload with one existing lead reference.</summary>
    private static string SchoolJson() => """
        {
            "name": "Test School",
            "lead_references": [
                { "id": "ref-1", "name": "Keep Updated", "slug": "keep-updated" }
            ]
        }
        """;

    #region Leads

    [Fact]
    public async Task Leads_ListAllAsync_Should_Forward_Filters_And_PageSize()
    {
        var (client, requests) = CreateClient((_, _, _) => Json(Paginated("""[{ "id": "l1" }]""")));

        var leads = await new LeadsResource(client).ListAllAsync(new Dictionary<string, string?>
        {
            ["is_email_unique"] = "false",
            ["has_student_profile"] = "true",
        }, pageSize: 25);

        leads.Should().HaveCount(1);
        requests.Should().HaveCount(1);
        var url = requests[0].Url;
        IsEndpoint(url, "leads/").Should().BeTrue();
        url.Should().Contain("is_email_unique=false")
            .And.Contain("has_student_profile=true")
            .And.Contain("page_size=25");
    }

    [Fact]
    public async Task Leads_ListPageAsync_Should_Send_Page_Params_And_Return_Count()
    {
        var (client, requests) = CreateClient((_, _, _) => Json("""
            { "count": 10, "next": null, "previous": null, "results": [{ "id": "l1" }] }
            """));

        var page = await new LeadsResource(client).ListPageAsync(page: 2, pageSize: 25);

        page.Count.Should().Be(10);
        page.Results.Should().HaveCount(1);
        IsEndpoint(requests[0].Url, "leads/").Should().BeTrue();
        requests[0].Url.Should().Contain("page=2").And.Contain("page_size=25");
    }

    [Fact]
    public async Task Leads_GetAsync_Should_Call_Lead_Detail_Endpoint()
    {
        var (client, requests) = CreateClient((_, _, _) => Json("""{ "id": "l1", "email": "parent@example.com" }"""));

        var lead = await new LeadsResource(client).GetAsync("l1");

        lead.GetProperty("email").GetString().Should().Be("parent@example.com");
        requests[0].Method.Should().Be(HttpMethod.Get);
        IsEndpoint(requests[0].Url, "leads/l1/").Should().BeTrue();
    }

    [Fact]
    public async Task Leads_CreateAsync_Should_Post_Body_To_Leads()
    {
        var (client, requests) = CreateClient((_, _, _) => Json("""{ "id": "new-lead", "email": "parent@example.com" }"""));

        var created = await new LeadsResource(client).CreateAsync(new
        {
            email = "parent@example.com",
            student_profile = "profile-uuid",
        });

        created.GetProperty("id").GetString().Should().Be("new-lead");
        requests[0].Method.Should().Be(HttpMethod.Post);
        IsEndpoint(requests[0].Url, "leads/").Should().BeTrue();

        var body = Parse(requests[0].Body!);
        body.GetProperty("email").GetString().Should().Be("parent@example.com");
        body.GetProperty("student_profile").GetString().Should().Be("profile-uuid");
    }

    [Fact]
    public async Task Leads_UpdateAsync_Should_Put_To_Lead_Endpoint()
    {
        var (client, requests) = CreateClient((_, _, _) => Json("""{ "id": "l1", "first_name": "Edited" }"""));

        var updated = await new LeadsResource(client).UpdateAsync("l1", new { id = "l1", first_name = "Edited" });

        updated.GetProperty("first_name").GetString().Should().Be("Edited");
        requests[0].Method.Should().Be(HttpMethod.Put);
        IsEndpoint(requests[0].Url, "leads/l1/").Should().BeTrue();
        Parse(requests[0].Body!).GetProperty("first_name").GetString().Should().Be("Edited");
    }

    [Fact]
    public async Task Leads_ReferencesAsync_Should_Call_Lead_References_With_PageSize_1000()
    {
        var (client, requests) = CreateClient((_, _, _) => Json(Paginated("""
            [{ "id": "ref-1", "name": "Keep Updated", "slug": "keep-updated" }]
            """)));

        var refs = await new LeadsResource(client).ReferencesAsync();

        refs.Should().HaveCount(1);
        refs[0].Id.Should().Be("ref-1");
        refs[0].Slug.Should().Be("keep-updated");
        IsEndpoint(requests[0].Url, "lead-references/").Should().BeTrue();
        requests[0].Url.Should().Contain("page_size=1000");
    }

    [Fact]
    public async Task ReferenceData_LeadReferencesAsync_Should_Call_Lead_References()
    {
        var (client, requests) = CreateClient((_, _, _) => Json(Paginated("""
            [{ "id": "ref-1", "name": "Keep Updated" }]
            """)));

        var refs = await new ReferenceDataResource(client).LeadReferencesAsync();

        refs.Should().HaveCount(1);
        refs[0].Name.Should().Be("Keep Updated");
        IsEndpoint(requests[0].Url, "lead-references/").Should().BeTrue();
    }

    #endregion

    #region Leads — CreateReferenceAsync

    [Fact]
    public async Task CreateReferenceAsync_Should_Round_Trip_School_Settings()
    {
        var (client, requests) = CreateClient((method, url, _) =>
        {
            if (IsEndpoint(url, "school/") && method == HttpMethod.Get)
                return Json(SchoolJson());
            if (IsEndpoint(url, "school/") && method == HttpMethod.Put)
                return Json("{}");
            if (IsEndpoint(url, "lead-references/"))
                return Json("""
                    { "count": 2, "next": null, "previous": null, "results": [
                        { "id": "ref-1", "name": "Keep Updated", "slug": "keep-updated" },
                        { "id": "ref-2", "name": "Open Day", "slug": "open-day" }
                    ] }
                    """);
            throw new InvalidOperationException($"Unexpected {method} {url}");
        });

        var created = await new LeadsResource(client).CreateReferenceAsync("Open Day", "open-day");

        created.Id.Should().Be("ref-2");
        created.Slug.Should().Be("open-day");

        requests.Should().HaveCount(3);
        requests[0].Method.Should().Be(HttpMethod.Get);
        IsEndpoint(requests[0].Url, "school/").Should().BeTrue();
        requests[1].Method.Should().Be(HttpMethod.Put);
        IsEndpoint(requests[1].Url, "school/").Should().BeTrue();
        requests[2].Method.Should().Be(HttpMethod.Get);
        IsEndpoint(requests[2].Url, "lead-references/").Should().BeTrue();

        var body = Parse(requests[1].Body!);
        body.GetProperty("name").GetString().Should().Be("Test School");
        var references = body.GetProperty("lead_references");
        references.GetArrayLength().Should().Be(2);
        // Existing references are preserved in the PUT body.
        references[0].GetProperty("id").GetString().Should().Be("ref-1");
        var added = references[1];
        added.GetProperty("name").GetString().Should().Be("Open Day");
        added.GetProperty("slug").GetString().Should().Be("open-day");
        added.GetProperty("confirmation_redirect_url").GetString().Should().Be("");
        added.GetProperty("is_removable").GetBoolean().Should().BeTrue();
    }

    [Fact]
    public async Task CreateReferenceAsync_Should_Derive_Slug_From_Name()
    {
        var (client, requests) = CreateClient((method, url, _) =>
        {
            if (IsEndpoint(url, "school/") && method == HttpMethod.Get)
                return Json(SchoolJson());
            if (IsEndpoint(url, "school/") && method == HttpMethod.Put)
                return Json("{}");
            return Json(Paginated("""
                [{ "id": "ref-2", "name": "Open Day 2027!", "slug": "open-day-2027" }]
                """));
        });

        var created = await new LeadsResource(client).CreateReferenceAsync("Open Day 2027!");

        created.Slug.Should().Be("open-day-2027");
        var body = Parse(requests[1].Body!);
        var references = body.GetProperty("lead_references");
        references[references.GetArrayLength() - 1].GetProperty("slug").GetString().Should().Be("open-day-2027");
    }

    [Fact]
    public void Slugify_Should_Lowercase_And_Collapse_Non_Alphanumerics()
    {
        LeadsResource.Slugify("Open Day 2027!").Should().Be("open-day-2027");
        LeadsResource.Slugify("  Keep -- Updated  ").Should().Be("keep-updated");
    }

    [Fact]
    public async Task CreateReferenceAsync_Should_Reject_Duplicate_Slug_Without_Writing()
    {
        var (client, requests) = CreateClient((_, _, _) => Json(SchoolJson()));

        Func<Task> act = () => new LeadsResource(client).CreateReferenceAsync("Keep Updated", "keep-updated");

        await act.Should().ThrowAsync<ArgumentException>().WithMessage("*keep-updated*");
        requests.Should().OnlyContain(r => r.Method == HttpMethod.Get);
    }

    [Fact]
    public async Task CreateReferenceAsync_Should_Throw_When_Missing_After_Save()
    {
        var (client, _) = CreateClient((method, url, _) =>
        {
            if (IsEndpoint(url, "school/") && method == HttpMethod.Get)
                return Json(SchoolJson());
            if (IsEndpoint(url, "school/") && method == HttpMethod.Put)
                return Json("{}");
            return Json("""{ "count": 0, "next": null, "previous": null, "results": [] }""");
        });

        Func<Task> act = () => new LeadsResource(client).CreateReferenceAsync("Open Day", "open-day");

        await act.Should().ThrowAsync<EnrolHQException>().WithMessage("*open-day*");
    }

    #endregion

    #region Forms — definitions

    [Fact]
    public async Task Forms_ListAllAsync_Should_Call_Staff_Forms_Endpoint()
    {
        var (client, requests) = CreateClient((_, _, _) => Json(Paginated("""
            [{ "id": "1", "title": "Enquiry", "form_slug": "stub-enquiry-form", "kind": "STUB" }]
            """)));

        var forms = await new FormsResource(client).ListAllAsync();

        forms.Should().HaveCount(1);
        IsEndpoint(requests[0].Url, "forms/staff/").Should().BeTrue();
    }

    [Fact]
    public async Task Forms_PublishedAsync_Should_Call_Parent_Facing_Forms_Endpoint()
    {
        var (client, requests) = CreateClient((_, _, _) => Json(Paginated("[]")));

        await new FormsResource(client).PublishedAsync();

        IsEndpoint(requests[0].Url, "forms/").Should().BeTrue();
        requests[0].Url.Should().NotContain("forms/staff/");
    }

    [Fact]
    public async Task Forms_GetAsync_Should_Be_Keyed_By_Slug()
    {
        var (client, requests) = CreateClient((_, _, _) => Json("""{ "id": "2", "form_slug": "photo-perm" }"""));

        var form = await new FormsResource(client).GetAsync("photo-perm");

        form.GetProperty("id").GetString().Should().Be("2");
        IsEndpoint(requests[0].Url, "forms/photo-perm/").Should().BeTrue();
    }

    [Fact]
    public async Task FindAsync_Should_Match_Title_Or_Slug_Case_Insensitively()
    {
        var (client, _) = CreateClient((_, _, _) => Json(Paginated("""
            [
                { "id": "1", "title": "Enquiry", "form_slug": "stub-enquiry-form" },
                { "id": "2", "title": "Photo Permission", "form_slug": "photo-perm" }
            ]
            """)));
        var resource = new FormsResource(client);

        var byTitle = await resource.FindAsync("photo permission");
        byTitle.Should().NotBeNull();
        byTitle!.Value.GetProperty("id").GetString().Should().Be("2");

        var bySlug = await resource.FindAsync("PHOTO-PERM");
        bySlug.Should().NotBeNull();
        bySlug!.Value.GetProperty("id").GetString().Should().Be("2");

        var none = await resource.FindAsync("nope");
        none.Should().BeNull();
    }

    #endregion

    #region Forms — submits

    [Fact]
    public async Task SubmitsAllAsync_Should_Pass_Filters_Through()
    {
        var (client, requests) = CreateClient((_, _, _) => Json(Paginated("[]")));

        await new FormsResource(client).SubmitsAllAsync(new Dictionary<string, string?>
        {
            ["form"] = "form-a",
            ["entry_year"] = "2027",
            ["is_completed"] = "true",
        });

        IsEndpoint(requests[0].Url, "forms/staff-submits/").Should().BeTrue();
        requests[0].Url.Should().Contain("form=form-a")
            .And.Contain("entry_year=2027")
            .And.Contain("is_completed=true");
    }

    [Fact]
    public async Task GetSubmitAsync_Should_Call_Submit_Detail_Endpoint()
    {
        var (client, requests) = CreateClient((_, _, _) => Json(SubmitJson()));

        var submit = await new FormsResource(client).GetSubmitAsync("submit-1");

        submit.GetProperty("id").GetString().Should().Be("submit-1");
        IsEndpoint(requests[0].Url, "forms/staff-submits/submit-1/").Should().BeTrue();
    }

    [Fact]
    public async Task SubmitsForApplicationAsync_Should_Annotate_Form_And_Application_Id()
    {
        var (client, requests) = CreateClient((_, url, _) =>
        {
            if (IsEndpoint(url, "applications/app-1/"))
                return Json("""
                    { "custom_form_submits": [
                        { "id": "submit-1", "form": "form-a", "completed_at": "x" },
                        { "id": "submit-2", "form": "form-b", "completed_at": "y" }
                    ] }
                    """);
            if (IsEndpoint(url, "forms/staff-submits/submit-1/"))
                return Json(SubmitJson("submit-1"));
            if (IsEndpoint(url, "forms/staff-submits/submit-2/"))
                return Json(SubmitJson("submit-2"));
            throw new InvalidOperationException($"Unexpected {url}");
        });

        var submits = await new FormsResource(client).SubmitsForApplicationAsync("app-1");

        submits.Select(s => s.FormId).Should().Equal("form-a", "form-b");
        submits.Select(s => s.Id).Should().Equal("submit-1", "submit-2");
        submits.Should().OnlyContain(s => s.ApplicationId == "app-1");
        submits[0].CompletedAt.Should().Be("2026-08-20T09:39:21+10:00");
        submits[0].Detail.GetProperty("payload").GetProperty("group_3_social_media").GetString().Should().Be("Yes");

        requests.Should().HaveCount(3);
        IsEndpoint(requests[0].Url, "applications/app-1/").Should().BeTrue();
        IsEndpoint(requests[1].Url, "forms/staff-submits/submit-1/").Should().BeTrue();
        IsEndpoint(requests[2].Url, "forms/staff-submits/submit-2/").Should().BeTrue();
    }

    [Fact]
    public async Task SubmitsForApplicationAsync_Should_Filter_By_Form()
    {
        var (client, requests) = CreateClient((_, url, _) =>
        {
            if (IsEndpoint(url, "applications/app-1/"))
                return Json("""
                    { "custom_form_submits": [
                        { "id": "submit-1", "form": "form-a" },
                        { "id": "submit-2", "form": "form-b" }
                    ] }
                    """);
            return Json(SubmitJson("submit-2"));
        });

        var submits = await new FormsResource(client).SubmitsForApplicationAsync("app-1", form: "form-b");

        submits.Should().HaveCount(1);
        submits[0].FormId.Should().Be("form-b");
        // Only the matching submit was fetched.
        requests.Should().HaveCount(2);
        IsEndpoint(requests[1].Url, "forms/staff-submits/submit-2/").Should().BeTrue();
    }

    [Fact]
    public async Task UpdateSubmitAsync_Should_Put_Payload_Wrapper()
    {
        var (client, requests) = CreateClient((_, _, _) => Json("""{ "id": "submit-1" }"""));

        await new FormsResource(client).UpdateSubmitAsync("submit-1", new { group_3_social_media = "No" });

        requests[0].Method.Should().Be(HttpMethod.Put);
        IsEndpoint(requests[0].Url, "forms/staff-submits/submit-1/").Should().BeTrue();
        var body = Parse(requests[0].Body!);
        body.GetProperty("payload").GetProperty("group_3_social_media").GetString().Should().Be("No");
    }

    [Fact]
    public async Task ReopenSubmitAsync_Should_Post_To_Re_Open_Action()
    {
        var (client, requests) = CreateClient((_, _, _) => new HttpResponseMessage(HttpStatusCode.NoContent));

        await new FormsResource(client).ReopenSubmitAsync("submit-1");

        requests[0].Method.Should().Be(HttpMethod.Post);
        IsEndpoint(requests[0].Url, "forms/staff-submits/submit-1/re_open/").Should().BeTrue();
    }

    [Fact]
    public async Task ExportSubmitsAsync_Should_Write_Csv_And_Pass_Filters()
    {
        var dest = Path.Combine(Path.GetTempPath(), "enrolhq-sdk-tests", Guid.NewGuid().ToString("N"), "submits.csv");
        try
        {
            var (client, requests) = CreateClient((_, _, _) => new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("a,b\n1,2", Encoding.UTF8, "text/csv"),
            });

            var path = await new FormsResource(client).ExportSubmitsAsync(dest, new Dictionary<string, string?>
            {
                ["form"] = "form-a",
                ["is_completed"] = "true",
            });

            path.Should().Be(dest);
            File.Exists(dest).Should().BeTrue();
            (await File.ReadAllTextAsync(dest)).Should().Be("a,b\n1,2");
            IsEndpoint(requests[0].Url, "forms/staff-submits/export/").Should().BeTrue();
            requests[0].Url.Should().Contain("form=form-a").And.Contain("is_completed=true");
        }
        finally
        {
            if (File.Exists(dest))
                File.Delete(dest);
        }
    }

    #endregion

    #region Forms — answers

    [Fact]
    public void AnswersFrom_Should_Label_Answers_And_Overlay_Payload()
    {
        var answers = FormsResource.AnswersFrom(Parse(SubmitJson()));

        // HTML content elements are skipped.
        answers.Select(a => a.Name).Should().Equal("contacts_of_emergency_1", "group_3_social_media", "notes");
        var byName = answers.ToDictionary(a => a.Name!);

        // payload wins over initial_payload
        byName["group_3_social_media"].Value.GetString().Should().Be("Yes");
        byName["group_3_social_media"].Label.Should().Be("Group 3: Social Media");
        byName["group_3_social_media"].Section.Should().Be("Photograph/Video Permission Form");
        byName["group_3_social_media"].ElementType.Should().Be("RADIO");
        byName["group_3_social_media"].HasValue.Should().BeTrue();

        // initial_payload fills in what payload doesn't carry
        var contacts = byName["contacts_of_emergency_1"];
        contacts.Value.ValueKind.Should().Be(JsonValueKind.Array);
        contacts.Value[0].GetProperty("first_name").GetString().Should().Be("Ada");
        contacts.IsProfileBacked.Should().BeTrue();
        contacts.Section.Should().Be("Emergency Contacts");

        byName["notes"].IsProfileBacked.Should().BeFalse();
        byName["notes"].Label.Should().Be("Anything else?"); // stripped
    }

    [Fact]
    public void AnswersFrom_Should_Handle_Missing_Schema_And_Payloads()
    {
        FormsResource.AnswersFrom(default).Should().BeEmpty();
        FormsResource.AnswersFrom(Parse("{}")).Should().BeEmpty();
        FormsResource.AnswersFrom(Parse("""
            { "form_schema": { "schema": [] }, "payload": null, "initial_payload": null }
            """)).Should().BeEmpty();
    }

    [Fact]
    public void AnswersFrom_Should_Leave_Value_Undefined_When_Unanswered()
    {
        var answers = FormsResource.AnswersFrom(Parse("""
            { "form_schema": { "schema": [ { "title": "S", "elements": [
                { "name": "q1", "label": "Q1", "element_type": "TEXT" }
            ] } ] } }
            """));

        answers.Should().ContainSingle();
        answers[0].Value.ValueKind.Should().Be(JsonValueKind.Undefined);
        answers[0].HasValue.Should().BeFalse();
    }

    [Fact]
    public async Task ConsentsAsync_Should_Return_Only_Choice_Elements()
    {
        var (client, requests) = CreateClient((_, _, _) => Json(SubmitJson()));

        var consents = await new FormsResource(client).ConsentsAsync("submit-1");

        consents.Should().HaveCount(1);
        consents.Should().ContainKey("group_3_social_media");
        consents["group_3_social_media"].Label.Should().Be("Group 3: Social Media");
        consents["group_3_social_media"].Value.GetString().Should().Be("Yes");
        IsEndpoint(requests[0].Url, "forms/staff-submits/submit-1/").Should().BeTrue();
    }

    [Fact]
    public async Task AnswersForApplicationAsync_Should_Shape_Records()
    {
        var (client, _) = CreateClient((_, url, _) =>
        {
            if (IsEndpoint(url, "applications/app-1/"))
                return Json("""{ "custom_form_submits": [{ "id": "submit-1", "form": "form-a" }] }""");
            return Json(SubmitJson());
        });

        var records = await new FormsResource(client).AnswersForApplicationAsync("app-1");

        records.Should().ContainSingle();
        var record = records[0];
        record.SubmitId.Should().Be("submit-1");
        record.FormId.Should().Be("form-a");
        record.CompletedAt.Should().Be("2026-08-20T09:39:21+10:00");
        record.StudentProfile.Should().BeNull();
        record.Answers.Select(a => a.Name).Should().Equal("contacts_of_emergency_1", "group_3_social_media", "notes");
    }

    [Fact]
    public async Task IterateAnswersAsync_Should_Dedupe_Profiles_And_Attach_Student_Profile()
    {
        // The submits list carries student_profile but no submit id, so
        // IterateAnswersAsync must resolve ids via the application detail.
        var (client, requests) = CreateClient((_, url, _) =>
        {
            if (IsEndpoint(url, "forms/staff-submits/"))
                return Json("""
                    { "count": 3, "next": null, "previous": null, "results": [
                        { "form_id": "form-a", "student_profile": { "id": "app-1", "first_name": "Ada", "last_name": "L" } },
                        { "form_id": "form-a", "student_profile": { "id": "app-1", "first_name": "Ada", "last_name": "L" } },
                        { "form_id": "form-a", "student_profile": {} }
                    ] }
                    """);
            if (IsEndpoint(url, "applications/app-1/"))
                return Json("""{ "custom_form_submits": [{ "id": "submit-1", "form": "form-a" }] }""");
            if (IsEndpoint(url, "forms/staff-submits/submit-1/"))
                return Json(SubmitJson());
            throw new InvalidOperationException($"Unexpected {url}");
        });

        var records = new List<FormAnswerRecord>();
        await foreach (var record in new FormsResource(client).IterateAnswersAsync(form: "form-a"))
            records.Add(record);

        // One record: the duplicate profile and the id-less row are both skipped.
        records.Should().ContainSingle();
        records[0].SubmitId.Should().Be("submit-1");
        records[0].StudentProfile.Should().NotBeNull();
        records[0].StudentProfile!.Value.GetProperty("id").GetString().Should().Be("app-1");
        records[0].StudentProfile!.Value.GetProperty("first_name").GetString().Should().Be("Ada");

        requests.Should().HaveCount(3);
        requests[0].Url.Should().Contain("form=form-a");
        IsEndpoint(requests[1].Url, "applications/app-1/").Should().BeTrue();
        IsEndpoint(requests[2].Url, "forms/staff-submits/submit-1/").Should().BeTrue();
    }

    #endregion

    #region Applications — nested profile data

    [Fact]
    public async Task Applications_Nested_Accessors_Should_Use_Detail_Endpoint()
    {
        var (client, requests) = CreateClient((_, _, _) => Json("""
            {
                "emergency_contacts": [{ "first_name": "Ada" }],
                "medical_data": { "medicare_number": "123" },
                "guardians": []
            }
            """));
        var resource = new ApplicationsResource(client);

        var contacts = await resource.EmergencyContactsAsync("app-1");
        contacts.Should().ContainSingle();
        contacts[0].GetProperty("first_name").GetString().Should().Be("Ada");

        var medical = await resource.MedicalDataAsync("app-1");
        medical.GetProperty("medicare_number").GetString().Should().Be("123");

        var guardians = await resource.GuardiansAsync("app-1");
        guardians.Should().BeEmpty();

        requests.Should().HaveCount(3);
        requests.Should().OnlyContain(r => IsEndpoint(r.Url, "applications/app-1/"));
    }

    [Fact]
    public async Task Applications_Nested_Accessors_Should_Default_When_Absent()
    {
        var (client, _) = CreateClient((_, _, _) => Json("{}"));
        var resource = new ApplicationsResource(client);

        (await resource.EmergencyContactsAsync("app-1")).Should().BeEmpty();
        (await resource.GuardiansAsync("app-1")).Should().BeEmpty();

        var medical = await resource.MedicalDataAsync("app-1");
        medical.ValueKind.Should().Be(JsonValueKind.Object);
        medical.GetRawText().Should().Be("{}");
    }

    #endregion

    #region Client wiring

    [Fact]
    public void Client_Should_Expose_Leads_Forms_And_Http()
    {
        // No request is made until a resource method is called.
        using var client = new EnrolHQClient("testschool.enrolhq.com.au", "tok");

        client.Leads.Should().NotBeNull();
        client.Forms.Should().NotBeNull();
        client.Http.Should().NotBeNull();
        client.Http.BuildUrl("integrations/sync/finished/")
            .Should().Be("https://testschool.enrolhq.com.au/api/v2/integrations/sync/finished/");
    }

    #endregion
}
