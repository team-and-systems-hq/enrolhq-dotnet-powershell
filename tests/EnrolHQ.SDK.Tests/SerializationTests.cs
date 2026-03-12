using System.Text.Json;
using EnrolHQ.SDK.Models;
using FluentAssertions;

namespace EnrolHQ.SDK.Tests;

/// <summary>
/// Tests for JSON serialization and deserialization of EnrolHQ API model types.
/// All models use [JsonPropertyName] attributes for explicit property mapping.
/// </summary>
public class SerializationTests
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    #region PaginatedResponse Tests

    [Fact]
    public void Should_Deserialize_PaginatedResponse_Correctly()
    {
        // Arrange
        var json = """
        {
            "count": 42,
            "next": "https://testschool.enrolhq.com.au/api/v2/applications-list/?page=3",
            "previous": "https://testschool.enrolhq.com.au/api/v2/applications-list/?page=1",
            "results": [
                {
                    "id": "abc-001",
                    "first_name": "Alice",
                    "last_name": "Johnson",
                    "application_status": 4,
                    "entry_year": 2026,
                    "entry_grade": 7
                },
                {
                    "id": "abc-002",
                    "first_name": "Bob",
                    "last_name": "Williams",
                    "application_status": 2,
                    "entry_year": 2026,
                    "entry_grade": 8
                }
            ]
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<PaginatedResponse<StudentProfile>>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Count.Should().Be(42);
        result.Next.Should().Be("https://testschool.enrolhq.com.au/api/v2/applications-list/?page=3");
        result.Previous.Should().Be("https://testschool.enrolhq.com.au/api/v2/applications-list/?page=1");
        result.Results.Should().HaveCount(2);
        result.Results[0].Id.Should().Be("abc-001");
        result.Results[0].FirstName.Should().Be("Alice");
        result.Results[0].ApplicationStatus.Should().Be(4);
        result.Results[1].EntryGrade.Should().Be(8);
    }

    [Fact]
    public void Should_Deserialize_PaginatedResponse_With_No_Next_Page()
    {
        // Arrange
        var json = """
        {
            "count": 2,
            "next": null,
            "previous": null,
            "results": [
                { "id": "abc-001", "first_name": "Alice", "last_name": "Johnson", "application_status": 0 }
            ]
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<PaginatedResponse<StudentProfile>>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Next.Should().BeNull();
        result.Previous.Should().BeNull();
        result.HasNext.Should().BeFalse();
    }

    [Fact]
    public void Should_Deserialize_PaginatedResponse_With_HasNext_True()
    {
        // Arrange
        var json = """
        {
            "count": 100,
            "next": "https://testschool.enrolhq.com.au/api/v2/applications-list/?page=2",
            "previous": null,
            "results": []
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<PaginatedResponse<StudentProfile>>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.HasNext.Should().BeTrue();
    }

    [Fact]
    public void Should_Deserialize_Empty_PaginatedResponse()
    {
        // Arrange
        var json = """
        {
            "count": 0,
            "next": null,
            "previous": null,
            "results": []
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<PaginatedResponse<StudentProfile>>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Count.Should().Be(0);
        result.Results.Should().BeEmpty();
        result.HasNext.Should().BeFalse();
    }

    #endregion

    #region CountResponse Tests

    [Fact]
    public void Should_Deserialize_CountResponse()
    {
        // Arrange
        var json = """
        {
            "count": 157,
            "pks_count": 157
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<CountResponse>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Count.Should().Be(157);
        result.PksCount.Should().Be(157);
    }

    [Fact]
    public void Should_Deserialize_CountResponse_Without_PksCount()
    {
        // Arrange
        var json = """{ "count": 42 }""";

        // Act
        var result = JsonSerializer.Deserialize<CountResponse>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Count.Should().Be(42);
        result.PksCount.Should().BeNull();
    }

    #endregion

    #region TokenRefreshResponse Tests

    [Fact]
    public void Should_Deserialize_TokenRefreshResponse()
    {
        // Arrange
        var json = """{ "access_token": "eyJhbGciOiJIUzI1NiJ9.test-token" }""";

        // Act
        var result = JsonSerializer.Deserialize<TokenRefreshResponse>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.AccessToken.Should().Be("eyJhbGciOiJIUzI1NiJ9.test-token");
    }

    [Fact]
    public void Should_Handle_Missing_AccessToken_In_RefreshResponse()
    {
        // Arrange
        var json = """{ "some_other_field": "value" }""";

        // Act
        var result = JsonSerializer.Deserialize<TokenRefreshResponse>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.AccessToken.Should().BeNull();
    }

    #endregion

    #region StudentProfile Tests

    [Fact]
    public void Should_Deserialize_StudentProfile_Correctly()
    {
        // Arrange
        var json = """
        {
            "id": "student-001",
            "first_name": "Alice",
            "last_name": "Johnson",
            "preferred_name": "Ali",
            "dob": "2013-03-15",
            "gender": 2,
            "gender_other": null,
            "entry_grade": 7,
            "entry_year": 2026,
            "entry_term": 1,
            "application_status": 4,
            "campus": "main-campus-uuid",
            "attendance_type": "day-uuid",
            "external_id": "EXT-001",
            "is_favorite": true,
            "how_hear": "Open Day",
            "created_at": "2025-06-15T10:30:00Z",
            "updated_at": "2025-08-01T14:00:00Z",
            "user_parent": {
                "id": "parent-001",
                "email": "robert.johnson@example.com",
                "first_name": "Robert",
                "last_name": "Johnson",
                "title": "Mr",
                "mobile_phone": "+61 412 345 678"
            }
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<StudentProfile>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be("student-001");
        result.FirstName.Should().Be("Alice");
        result.LastName.Should().Be("Johnson");
        result.PreferredName.Should().Be("Ali");
        result.Dob.Should().Be("2013-03-15");
        result.Gender.Should().Be(2);
        result.EntryGrade.Should().Be(7);
        result.EntryYear.Should().Be(2026);
        result.EntryTerm.Should().Be(1);
        result.ApplicationStatus.Should().Be(4);
        result.ExternalId.Should().Be("EXT-001");
        result.IsFavorite.Should().BeTrue();
        result.HowHear.Should().Be("Open Day");
        result.CreatedAt.Should().Be("2025-06-15T10:30:00Z");

        result.UserParent.Should().NotBeNull();
        result.UserParent!.Email.Should().Be("robert.johnson@example.com");
        result.UserParent.FirstName.Should().Be("Robert");
        result.UserParent.MobilePhone.Should().Be("+61 412 345 678");
    }

    [Fact]
    public void Should_Handle_Null_Optional_Fields_In_StudentProfile()
    {
        // Arrange
        var json = """
        {
            "id": "student-002",
            "first_name": "Bob",
            "last_name": "Williams",
            "application_status": 0,
            "preferred_name": null,
            "dob": null,
            "gender": null,
            "gender_other": null,
            "entry_grade": null,
            "entry_year": null,
            "entry_term": null,
            "campus": null,
            "attendance_type": null,
            "external_id": null,
            "is_favorite": null,
            "how_hear": null,
            "created_at": null,
            "updated_at": null,
            "user_parent": null,
            "non_user_parent": null
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<StudentProfile>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be("student-002");
        result.FirstName.Should().Be("Bob");
        result.PreferredName.Should().BeNull();
        result.Dob.Should().BeNull();
        result.Gender.Should().BeNull();
        result.EntryGrade.Should().BeNull();
        result.EntryYear.Should().BeNull();
        result.Campus.Should().BeNull();
        result.UserParent.Should().BeNull();
        result.NonUserParent.Should().BeNull();
    }

    [Fact]
    public void Should_Handle_Missing_Optional_Fields_In_StudentProfile()
    {
        // Arrange -- minimal JSON with only required fields
        var json = """
        {
            "id": "student-003",
            "first_name": "Charlie",
            "last_name": "Brown",
            "application_status": 1
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<StudentProfile>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be("student-003");
        result.FirstName.Should().Be("Charlie");
        result.PreferredName.Should().BeNull();
        result.Dob.Should().BeNull();
        result.EntryGrade.Should().BeNull();
        result.UserParent.Should().BeNull();
    }

    [Fact]
    public void Should_Deserialize_ParentSummary()
    {
        // Arrange
        var json = """
        {
            "id": "parent-001",
            "email": "jane.doe@example.com",
            "first_name": "Jane",
            "last_name": "Doe",
            "title": "Mrs",
            "mobile_phone": "+61 400 123 456"
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<ParentSummary>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be("parent-001");
        result.Email.Should().Be("jane.doe@example.com");
        result.FirstName.Should().Be("Jane");
        result.LastName.Should().Be("Doe");
        result.Title.Should().Be("Mrs");
        result.MobilePhone.Should().Be("+61 400 123 456");
    }

    [Fact]
    public void Should_Deserialize_StudentProfile_With_Both_Parents()
    {
        // Arrange
        var json = """
        {
            "id": "student-004",
            "first_name": "Diana",
            "last_name": "Lee",
            "application_status": 2,
            "user_parent": {
                "id": "p1",
                "email": "mother@example.com",
                "first_name": "Michelle",
                "last_name": "Lee"
            },
            "non_user_parent": {
                "id": "p2",
                "email": "father@example.com",
                "first_name": "David",
                "last_name": "Lee"
            }
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<StudentProfile>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.UserParent.Should().NotBeNull();
        result.UserParent!.FirstName.Should().Be("Michelle");
        result.NonUserParent.Should().NotBeNull();
        result.NonUserParent!.FirstName.Should().Be("David");
    }

    #endregion

    #region ApplicationDocument Tests

    [Fact]
    public void Should_Deserialize_ApplicationDocument()
    {
        // Arrange
        var json = """
        {
            "id": "doc-001",
            "file": "https://storage.example.com/docs/report.pdf",
            "filename": "school-report-2025.pdf",
            "student_profile": "student-001",
            "parent": null,
            "group": "group-uuid",
            "group_kind": "SCHOOL_REPORT",
            "created_at": "2025-06-16T08:00:00Z",
            "staff": null,
            "user": "user-uuid",
            "is_submitted": true,
            "is_verified": false
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<ApplicationDocument>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be("doc-001");
        result.Filename.Should().Be("school-report-2025.pdf");
        result.StudentProfile.Should().Be("student-001");
        result.GroupKind.Should().Be("SCHOOL_REPORT");
        result.IsSubmitted.Should().BeTrue();
        result.IsVerified.Should().BeFalse();
    }

    [Fact]
    public void Should_Handle_Null_Fields_In_Document()
    {
        // Arrange
        var json = """
        {
            "id": "doc-002",
            "file": null,
            "filename": "pending.pdf",
            "student_profile": null,
            "parent": null,
            "group": null,
            "group_kind": null,
            "created_at": null,
            "staff": null,
            "user": null,
            "is_submitted": null,
            "is_verified": null
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<ApplicationDocument>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be("doc-002");
        result.File.Should().BeNull();
        result.StudentProfile.Should().BeNull();
        result.GroupKind.Should().BeNull();
        result.IsSubmitted.Should().BeNull();
        result.IsVerified.Should().BeNull();
    }

    #endregion

    #region Note Tests

    [Fact]
    public void Should_Deserialize_Note()
    {
        // Arrange
        var json = """
        {
            "id": "note-001",
            "created_at": "2025-07-01T14:00:00Z",
            "created_by": "admin@school.edu.au",
            "is_pinned": true,
            "text": "Interview completed - positive outcome",
            "student_profile": "student-001",
            "event": null
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<Note>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be("note-001");
        result.Text.Should().Be("Interview completed - positive outcome");
        result.IsPinned.Should().BeTrue();
        result.StudentProfile.Should().Be("student-001");
        result.Event.Should().BeNull();
    }

    #endregion

    #region Campus Tests

    [Fact]
    public void Should_Deserialize_Campus()
    {
        // Arrange
        var json = """
        {
            "id": "campus-001",
            "name": "Main Campus",
            "slug": "main-campus",
            "registrar_title": "Head of Admissions",
            "email": "admissions@school.edu.au",
            "telephone": "+61 2 1234 5678",
            "residential_address": {
                "id": "addr-001",
                "street_address": "123 School Street",
                "suburb": "Greenville",
                "state": "NSW",
                "postcode": "2000",
                "country": "AU"
            }
        }
        """;

        // Act
        var result = JsonSerializer.Deserialize<Campus>(json, JsonOptions);

        // Assert
        result.Should().NotBeNull();
        result!.Id.Should().Be("campus-001");
        result.Name.Should().Be("Main Campus");
        result.Slug.Should().Be("main-campus");
        result.Email.Should().Be("admissions@school.edu.au");
        result.ResidentialAddress.Should().NotBeNull();
        result.ResidentialAddress!.StreetAddress.Should().Be("123 School Street");
        result.ResidentialAddress.State.Should().Be("NSW");
        result.ResidentialAddress.Postcode.Should().Be("2000");
    }

    #endregion

    #region Round-Trip Tests

    [Fact]
    public void Should_Roundtrip_StudentProfile()
    {
        // Arrange
        var original = new StudentProfile
        {
            Id = "rt-001",
            FirstName = "RoundTrip",
            LastName = "Test",
            ApplicationStatus = 2,
            EntryYear = 2026,
            EntryGrade = 7,
            PreferredName = "RT",
            Dob = "2013-05-20"
        };

        // Act
        var json = JsonSerializer.Serialize(original, JsonOptions);
        var deserialized = JsonSerializer.Deserialize<StudentProfile>(json, JsonOptions);

        // Assert
        deserialized.Should().NotBeNull();
        deserialized!.Id.Should().Be(original.Id);
        deserialized.FirstName.Should().Be(original.FirstName);
        deserialized.ApplicationStatus.Should().Be(original.ApplicationStatus);
        deserialized.EntryYear.Should().Be(original.EntryYear);
        deserialized.EntryGrade.Should().Be(original.EntryGrade);
        deserialized.PreferredName.Should().Be(original.PreferredName);
    }

    [Fact]
    public void Should_Roundtrip_PaginatedResponse()
    {
        // Arrange
        var original = new PaginatedResponse<StudentProfile>
        {
            Count = 1,
            Next = null,
            Previous = null,
            Results = new List<StudentProfile>
            {
                new()
                {
                    Id = "rt-002",
                    FirstName = "Solo",
                    LastName = "Result",
                    ApplicationStatus = 0
                }
            }
        };

        // Act
        var json = JsonSerializer.Serialize(original, JsonOptions);
        var deserialized = JsonSerializer.Deserialize<PaginatedResponse<StudentProfile>>(json, JsonOptions);

        // Assert
        deserialized.Should().NotBeNull();
        deserialized!.Count.Should().Be(1);
        deserialized.HasNext.Should().BeFalse();
        deserialized.Results.Should().HaveCount(1);
        deserialized.Results[0].FirstName.Should().Be("Solo");
    }

    #endregion
}
