using EnrolHQ.SDK.Models.Enums;
using FluentAssertions;

namespace EnrolHQ.SDK.Tests;

/// <summary>
/// Pins the application status codes to the values the EnrolHQ API uses.
/// </summary>
public class ApplicationStatusTests
{
    [Theory]
    [InlineData(ApplicationStatus.RegisterInterest, -1)]
    [InlineData(ApplicationStatus.EnquiryOnline, 0)]
    [InlineData(ApplicationStatus.EnquiryEvent, 1)]
    [InlineData(ApplicationStatus.Eoi, 2)]
    [InlineData(ApplicationStatus.Enrolment, 3)]
    [InlineData(ApplicationStatus.Orientation, 4)]
    [InlineData(ApplicationStatus.Community, 5)]
    [InlineData(ApplicationStatus.Alumni, 6)]
    [InlineData(ApplicationStatus.Trashed, 7)]
    [InlineData(ApplicationStatus.Declined, 8)]
    [InlineData(ApplicationStatus.Waitlist, 9)]
    [InlineData(ApplicationStatus.ReservedOffer, 10)]
    [InlineData(ApplicationStatus.NotProceeding, 11)]
    [InlineData(ApplicationStatus.EnrolmentOffer, 12)]
    [InlineData(ApplicationStatus.Interview, 13)]
    [InlineData(ApplicationStatus.Pending, 14)]
    [InlineData(ApplicationStatus.Custom1, 15)]
    [InlineData(ApplicationStatus.Custom8, 22)]
    [InlineData(ApplicationStatus.Custom9, 23)]
    [InlineData(ApplicationStatus.Custom16, 30)]
    public void Should_Match_Api_Status_Code(ApplicationStatus status, int expected)
    {
        ((int)status).Should().Be(expected);
    }

    [Fact]
    public void Should_Define_Every_Code_From_Minus_One_To_Thirty()
    {
        var codes = Enum.GetValues<ApplicationStatus>().Select(status => (int)status);

        codes.Should().BeEquivalentTo(Enumerable.Range(-1, 32));
    }
}
