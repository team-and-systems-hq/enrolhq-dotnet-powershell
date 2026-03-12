using System.Net;
using System.Text;
using EnrolHQ.SDK.Http;
using EnrolHQ.SDK.Models;
using EnrolHQ.SDK.Resources;
using FluentAssertions;
using Moq;
using Moq.Protected;

namespace EnrolHQ.SDK.Tests;

/// <summary>
/// Tests for DocumentsResource, particularly the UploadAsync method
/// that was rewritten to use ByteArrayContent for retry safety.
/// </summary>
public class DocumentsResourceTests
{
    private const string BaseUrl = "https://testschool.enrolhq.com.au/api/v2/";

    private static (DocumentsResource resource, Mock<HttpMessageHandler> mockHandler) CreateResource(
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
        var enrolHqClient = new EnrolHQHttpClient(BaseUrl, httpClient);
        var resource = new DocumentsResource(enrolHqClient);
        return (resource, mockHandler);
    }

    [Fact]
    public async Task UploadAsync_Should_Send_Multipart_With_ByteArrayContent()
    {
        // Arrange — create a temp file to upload
        var tempFile = Path.GetTempFileName();
        var fileContent = "test file content for upload"u8.ToArray();
        await File.WriteAllBytesAsync(tempFile, fileContent);

        HttpRequestMessage? capturedRequest = null;

        var (resource, _) = CreateResource(async (req, ct) =>
        {
            capturedRequest = req;
            return new HttpResponseMessage(HttpStatusCode.Created)
            {
                Content = new StringContent("""
                {
                    "id": "doc-001",
                    "filename": "test.txt",
                    "student_profile": "student-001",
                    "group_kind": "SCHOOL_REPORT",
                    "is_submitted": false,
                    "is_verified": false
                }
                """, Encoding.UTF8, "application/json")
            };
        });

        try
        {
            // Act
            var result = await resource.UploadAsync("student-001", tempFile, "SCHOOL_REPORT", "test.txt");

            // Assert
            result.Should().NotBeNull();
            result!.Id.Should().Be("doc-001");
            result.Filename.Should().Be("test.txt");
            result.GroupKind.Should().Be("SCHOOL_REPORT");

            capturedRequest.Should().NotBeNull();
            capturedRequest!.Method.Should().Be(HttpMethod.Post);
            capturedRequest.Content.Should().BeOfType<MultipartFormDataContent>();
        }
        finally
        {
            File.Delete(tempFile);
        }
    }

    [Fact]
    public async Task UploadAsync_Should_Default_Filename_To_File_Name()
    {
        var tempDir = Path.GetTempPath();
        var tempFile = Path.Combine(tempDir, "my-report.pdf");
        await File.WriteAllTextAsync(tempFile, "fake pdf content");

        string? capturedFilename = null;

        var (resource, _) = CreateResource(async (req, ct) =>
        {
            // Read the multipart content to find the filename field
            if (req.Content is MultipartFormDataContent multipart)
            {
                foreach (var part in multipart)
                {
                    if (part.Headers.ContentDisposition?.Name?.Trim('"') == "filename")
                    {
                        capturedFilename = await part.ReadAsStringAsync(ct);
                    }
                }
            }

            return new HttpResponseMessage(HttpStatusCode.Created)
            {
                Content = new StringContent("""
                {
                    "id": "doc-002",
                    "filename": "my-report.pdf",
                    "student_profile": "student-001",
                    "group_kind": "BIRTH_CERTIFICATE"
                }
                """, Encoding.UTF8, "application/json")
            };
        });

        try
        {
            await resource.UploadAsync("student-001", tempFile, "BIRTH_CERTIFICATE");

            capturedFilename.Should().Be("my-report.pdf",
                "filename should default to the file name when not explicitly provided");
        }
        finally
        {
            File.Delete(tempFile);
        }
    }

    [Fact]
    public async Task UploadAsync_Should_Include_All_Required_Form_Fields()
    {
        var tempFile = Path.GetTempFileName();
        await File.WriteAllTextAsync(tempFile, "content");

        var fieldNames = new List<string>();

        var (resource, _) = CreateResource(async (req, ct) =>
        {
            if (req.Content is MultipartFormDataContent multipart)
            {
                foreach (var part in multipart)
                {
                    var name = part.Headers.ContentDisposition?.Name?.Trim('"');
                    if (name is not null)
                        fieldNames.Add(name);
                }
            }

            return new HttpResponseMessage(HttpStatusCode.Created)
            {
                Content = new StringContent("""{"id": "doc-003"}""",
                    Encoding.UTF8, "application/json")
            };
        });

        try
        {
            await resource.UploadAsync("student-001", tempFile, "PASSPORT", "passport.jpg");

            fieldNames.Should().Contain("filename");
            fieldNames.Should().Contain("group_kind");
            fieldNames.Should().Contain("student_profile");
            fieldNames.Should().Contain("file");
        }
        finally
        {
            File.Delete(tempFile);
        }
    }

    [Fact]
    public async Task UploadAsync_Uses_ByteArrayContent_Not_StreamContent()
    {
        // This test verifies the fix: ByteArrayContent is used instead of StreamContent
        // so that retries don't fail due to consumed streams
        var tempFile = Path.GetTempFileName();
        await File.WriteAllTextAsync(tempFile, "retry-safe content");

        Type? fileContentType = null;

        var (resource, _) = CreateResource(async (req, ct) =>
        {
            if (req.Content is MultipartFormDataContent multipart)
            {
                foreach (var part in multipart)
                {
                    if (part.Headers.ContentDisposition?.Name?.Trim('"') == "file")
                    {
                        fileContentType = part.GetType();
                    }
                }
            }

            return new HttpResponseMessage(HttpStatusCode.Created)
            {
                Content = new StringContent("""{"id": "doc-004"}""",
                    Encoding.UTF8, "application/json")
            };
        });

        try
        {
            await resource.UploadAsync("student-001", tempFile, "PHOTO");

            fileContentType.Should().Be(typeof(ByteArrayContent),
                "file content should use ByteArrayContent for retry safety, not StreamContent");
        }
        finally
        {
            File.Delete(tempFile);
        }
    }

    [Fact]
    public async Task DeleteAsync_Should_Call_Correct_Endpoint()
    {
        string? capturedUrl = null;
        HttpMethod? capturedMethod = null;

        var (resource, _) = CreateResource(async (req, ct) =>
        {
            capturedUrl = req.RequestUri?.ToString();
            capturedMethod = req.Method;
            return new HttpResponseMessage(HttpStatusCode.NoContent);
        });

        await resource.DeleteAsync("doc-001");

        capturedUrl.Should().Contain("application-documents/doc-001/");
        capturedMethod.Should().Be(HttpMethod.Delete);
    }
}
