using System.Text.Json;

namespace EnrolHQ.SDK.Models;

/// <summary>
/// A custom-form submission fetched via
/// <see cref="Resources.FormsResource.SubmitsForApplicationAsync"/>, annotated
/// with the identifiers the submit detail endpoint omits.
/// </summary>
/// <remarks>
/// The <c>forms/staff-submits/{id}/</c> response does not carry the form id or
/// the application id — its <c>form_schema.id</c> is a schema <em>version</em>
/// id, not the form's id — so both are read off the application detail and
/// attached here.
/// </remarks>
public class FormSubmit
{
    /// <summary>The submit UUID.</summary>
    public string Id { get; init; } = "";

    /// <summary>The form UUID (from <c>custom_form_submits[].form</c> on the application detail).</summary>
    public string? FormId { get; init; }

    /// <summary>The application / student profile UUID the submit belongs to.</summary>
    public string ApplicationId { get; init; } = "";

    /// <summary>When the parent completed the submission, if they did.</summary>
    public string? CompletedAt { get; init; }

    /// <summary>
    /// The full <c>forms/staff-submits/{id}/</c> response, including
    /// <c>payload</c>, <c>initial_payload</c> and <c>form_schema</c>.
    /// </summary>
    public JsonElement Detail { get; init; }
}

/// <summary>
/// One answer from a form submission, joined against the form schema so it
/// carries the question text the parent actually saw.
/// </summary>
public class FormAnswer
{
    /// <summary>The section title the element appears under.</summary>
    public string Section { get; init; } = "";

    /// <summary>The element's field name (the key in <c>payload</c>), e.g. <c>group_3_social_media</c>.</summary>
    public string? Name { get; init; }

    /// <summary>The question label shown to the parent (whitespace-trimmed).</summary>
    public string Label { get; init; } = "";

    /// <summary>The element type, e.g. <c>RADIO</c>, <c>CHECKBOX</c>, <c>TEXT</c>, <c>EMERGENCY_CONTACTS</c>.</summary>
    public string ElementType { get; init; } = "";

    /// <summary>
    /// The answer. <see cref="JsonValueKind.Undefined"/> when the submit carries
    /// no value for this element. Not always a scalar: <c>EMERGENCY_CONTACTS</c>
    /// is an array, <c>MEDICAL_DATA</c> an object, checkbox groups an array of
    /// selected options, and a <c>DOCUMENTS</c> element is a document
    /// <em>group</em> whose files live under its <c>documents</c> property.
    /// </summary>
    public JsonElement Value { get; init; }

    /// <summary>
    /// True for elements whose answers are written back onto the student
    /// profile (emergency contacts, medical data, parent/guardian contacts,
    /// documents). Their value here is a snapshot taken when the form was
    /// opened; read the application detail for the current value.
    /// </summary>
    public bool IsProfileBacked { get; init; }

    /// <summary>True when <see cref="Value"/> is neither undefined nor JSON null.</summary>
    public bool HasValue => Value.ValueKind is not (JsonValueKind.Undefined or JsonValueKind.Null);
}

/// <summary>Labelled answers for one submission.</summary>
public class FormAnswerRecord
{
    /// <summary>The submit UUID.</summary>
    public string SubmitId { get; init; } = "";

    /// <summary>The form UUID the submission belongs to.</summary>
    public string? FormId { get; init; }

    /// <summary>When the parent completed the submission, if they did.</summary>
    public string? CompletedAt { get; init; }

    /// <summary>The submission's answers, in form order.</summary>
    public List<FormAnswer> Answers { get; init; } = [];

    /// <summary>
    /// The nested <c>student_profile</c> summary from the submits list. Only
    /// populated by <see cref="Resources.FormsResource.IterateAnswersAsync"/>.
    /// </summary>
    public JsonElement? StudentProfile { get; init; }
}

/// <summary>A yes/no permission (consent) answer.</summary>
public class ConsentAnswer
{
    /// <summary>The question label shown to the parent.</summary>
    public string Label { get; init; } = "";

    /// <summary>The selected answer (a string for RADIO/CHECKBOX, an array for CHECKBOX_GROUP).</summary>
    public JsonElement Value { get; init; }
}
