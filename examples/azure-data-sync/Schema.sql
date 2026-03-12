-- ============================================================================
-- EnrolHQ -> Azure SQL sync schema
-- Run this once against your target database to create the tables.
--
-- Designed for:
--   - Power BI reporting
--   - SIS integration staging
--   - Compliance/audit trail
-- ============================================================================

-- Applications (one row per student profile)
CREATE TABLE dbo.EnrolHQ_Applications (
    Id                  NVARCHAR(50)        NOT NULL PRIMARY KEY,
    FirstName           NVARCHAR(200)       NULL,
    LastName            NVARCHAR(200)       NULL,
    PreferredName       NVARCHAR(200)       NULL,
    Dob                 DATE                NULL,
    Gender              INT                 NULL,
    EntryGrade          INT                 NULL,
    EntryYear           INT                 NULL,
    EntryTerm           INT                 NULL,
    ApplicationStatus   INT                 NOT NULL DEFAULT 0,
    StatusLabel         NVARCHAR(50)        NULL,     -- human-readable status
    Campus              NVARCHAR(200)       NULL,
    AttendanceType      NVARCHAR(200)       NULL,
    ExternalId          NVARCHAR(200)       NULL,     -- your SIS student ID
    IsFavorite          BIT                 NULL,
    HowHear             NVARCHAR(500)       NULL,
    CreatedAt           DATETIMEOFFSET      NULL,
    UpdatedAt           DATETIMEOFFSET      NULL,

    -- Primary parent
    ParentFirstName     NVARCHAR(200)       NULL,
    ParentLastName      NVARCHAR(200)       NULL,
    ParentEmail         NVARCHAR(300)       NULL,
    ParentPhone         NVARCHAR(50)        NULL,

    -- Secondary parent
    Parent2FirstName    NVARCHAR(200)       NULL,
    Parent2LastName     NVARCHAR(200)       NULL,
    Parent2Email        NVARCHAR(300)       NULL,
    Parent2Phone        NVARCHAR(50)        NULL,

    -- Sync metadata
    SyncedAt            DATETIMEOFFSET      NOT NULL DEFAULT SYSDATETIMEOFFSET()
);

-- Status change audit trail (tracks every status transition)
CREATE TABLE dbo.EnrolHQ_StatusHistory (
    Id                  INT IDENTITY(1,1)   PRIMARY KEY,
    ApplicationId       NVARCHAR(50)        NOT NULL,
    PreviousStatus      INT                 NULL,
    NewStatus           INT                 NOT NULL,
    PreviousLabel       NVARCHAR(50)        NULL,
    NewLabel            NVARCHAR(50)        NULL,
    DetectedAt          DATETIMEOFFSET      NOT NULL DEFAULT SYSDATETIMEOFFSET(),

    CONSTRAINT FK_StatusHistory_App
        FOREIGN KEY (ApplicationId) REFERENCES dbo.EnrolHQ_Applications(Id)
);

CREATE NONCLUSTERED INDEX IX_StatusHistory_AppId
    ON dbo.EnrolHQ_StatusHistory(ApplicationId, DetectedAt DESC);

-- Campuses reference table
CREATE TABLE dbo.EnrolHQ_Campuses (
    Id                  NVARCHAR(50)        NOT NULL PRIMARY KEY,
    Name                NVARCHAR(200)       NOT NULL,
    Slug                NVARCHAR(100)       NULL,
    Email               NVARCHAR(300)       NULL,
    Telephone           NVARCHAR(50)        NULL,
    SyncedAt            DATETIMEOFFSET      NOT NULL DEFAULT SYSDATETIMEOFFSET()
);

-- Daily snapshot for trend reporting (one row per status per day)
CREATE TABLE dbo.EnrolHQ_DailySnapshot (
    SnapshotDate        DATE                NOT NULL,
    EntryYear           INT                 NOT NULL,
    ApplicationStatus   INT                 NOT NULL,
    StatusLabel         NVARCHAR(50)        NULL,
    Campus              NVARCHAR(200)       NULL,
    ApplicationCount    INT                 NOT NULL,

    CONSTRAINT PK_DailySnapshot
        PRIMARY KEY (SnapshotDate, EntryYear, ApplicationStatus, Campus)
);

-- Sync run log (for monitoring and troubleshooting)
CREATE TABLE dbo.EnrolHQ_SyncLog (
    Id                  INT IDENTITY(1,1)   PRIMARY KEY,
    StartedAt           DATETIMEOFFSET      NOT NULL,
    CompletedAt         DATETIMEOFFSET      NULL,
    RecordsSynced       INT                 NULL,
    StatusChanges       INT                 NULL,
    ErrorMessage        NVARCHAR(MAX)       NULL,
    Status              NVARCHAR(20)        NOT NULL DEFAULT 'Running'  -- Running, Success, Failed
);

-- ============================================================================
-- Status label lookup (convenience view)
-- ============================================================================
GO
CREATE OR ALTER VIEW dbo.vw_EnrolHQ_StatusLabels AS
SELECT * FROM (VALUES
    (-1, 'Archived'),
    (0,  'Enquiry (Online)'),
    (1,  'Enquiry (Manual)'),
    (2,  'EOI'),
    (3,  'Interview'),
    (4,  'Enrolment'),
    (5,  'Offer of Enrolment'),
    (6,  'Accepted'),
    (7,  'Enrolled'),
    (8,  'Deferred'),
    (9,  'Waitlisted'),
    (10, 'Withdrawn by Parent'),
    (11, 'Declined by School'),
    (12, 'Closed'),
    (13, 'Enquiry (Event)'),
    (14, 'Enquiry (Tour)'),
    (15, 'Enquiry (Referred)'),
    (16, 'Enquiry (Phone)'),
    (17, 'Enquiry (Walk-in)'),
    (18, 'Reserved'),
    (19, 'Offer of Reserved Place'),
    (20, 'Accepted Reserved Place'),
    (21, 'Declined by Parent'),
    (22, 'Cancelled by School')
) AS T(StatusCode, StatusLabel);
GO

-- ============================================================================
-- Useful reporting views
-- ============================================================================

-- Current pipeline summary (plug straight into Power BI)
CREATE OR ALTER VIEW dbo.vw_EnrolHQ_Pipeline AS
SELECT
    a.EntryYear,
    a.EntryGrade,
    a.ApplicationStatus,
    s.StatusLabel,
    a.Campus,
    COUNT(*)                AS ApplicationCount,
    COUNT(CASE WHEN a.CreatedAt >= DATEADD(DAY, -7, GETDATE()) THEN 1 END)  AS NewLast7Days,
    COUNT(CASE WHEN a.CreatedAt >= DATEADD(DAY, -30, GETDATE()) THEN 1 END) AS NewLast30Days
FROM dbo.EnrolHQ_Applications a
LEFT JOIN dbo.vw_EnrolHQ_StatusLabels s ON a.ApplicationStatus = s.StatusCode
GROUP BY a.EntryYear, a.EntryGrade, a.ApplicationStatus, s.StatusLabel, a.Campus;
GO

-- Parent contact list (for mail merges, comms)
CREATE OR ALTER VIEW dbo.vw_EnrolHQ_ParentContacts AS
SELECT
    a.Id                AS ApplicationId,
    a.FirstName         AS StudentFirstName,
    a.LastName          AS StudentLastName,
    a.EntryYear,
    a.EntryGrade,
    s.StatusLabel,
    a.Campus,
    a.ParentFirstName,
    a.ParentLastName,
    a.ParentEmail,
    a.ParentPhone
FROM dbo.EnrolHQ_Applications a
LEFT JOIN dbo.vw_EnrolHQ_StatusLabels s ON a.ApplicationStatus = s.StatusCode
WHERE a.ApplicationStatus NOT IN (-1, 10, 11, 12, 21, 22);   -- exclude closed/archived
GO
