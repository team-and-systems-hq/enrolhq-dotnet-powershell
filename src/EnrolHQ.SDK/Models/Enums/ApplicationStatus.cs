namespace EnrolHQ.SDK.Models.Enums;

/// <summary>
/// Application workflow status codes, as defined by the EnrolHQ API.
/// Schools can rename statuses; read the labels a school actually uses from
/// <c>ReferenceData.ApplicationStatusSettingsAsync()</c>.
/// </summary>
public enum ApplicationStatus
{
    RegisterInterest = -1,
    EnquiryOnline = 0,
    EnquiryEvent = 1,
    Eoi = 2,
    Enrolment = 3,
    Orientation = 4,
    Community = 5,
    Alumni = 6,
    Trashed = 7,
    Declined = 8,
    Waitlist = 9,
    ReservedOffer = 10,
    NotProceeding = 11,
    EnrolmentOffer = 12,
    Interview = 13,
    Pending = 14,
    Custom1 = 15,
    Custom2 = 16,
    Custom3 = 17,
    Custom4 = 18,
    Custom5 = 19,
    Custom6 = 20,
    Custom7 = 21,
    Custom8 = 22,
    Custom9 = 23,
    Custom10 = 24,
    Custom11 = 25,
    Custom12 = 26,
    Custom13 = 27,
    Custom14 = 28,
    Custom15 = 29,
    Custom16 = 30,
}
