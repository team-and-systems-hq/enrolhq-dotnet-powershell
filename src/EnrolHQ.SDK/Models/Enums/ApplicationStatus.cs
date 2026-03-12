namespace EnrolHQ.SDK.Models.Enums;

/// <summary>Application workflow status codes.</summary>
public enum ApplicationStatus
{
    Archived = -1,
    EnquiryOnline = 0,
    EnquiryManual = 1,
    Eoi = 2,
    Interview = 3,
    Enrolment = 4,
    OfferEnrolment = 5,
    Accepted = 6,
    Enrolled = 7,
    Deferred = 8,
    Waitlisted = 9,
    WithdrawnByParent = 10,
    DeclinedBySchool = 11,
    Closed = 12,
    EnquiryEvent = 13,
    EnquiryTour = 14,
    EnquiryReferred = 15,
    EnquiryPhone = 16,
    EnquiryWalkIn = 17,
    Reserved = 18,
    OfferReservedPlace = 19,
    AcceptedReservedPlace = 20,
    DeclinedByParent = 21,
    CancelledBySchool = 22,
}
