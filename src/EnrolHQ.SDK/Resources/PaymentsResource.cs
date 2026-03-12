using System.Text.Json;
using EnrolHQ.SDK.Http;

namespace EnrolHQ.SDK.Resources;

/// <summary>Manage order lines and payments.</summary>
public class PaymentsResource : BaseResource
{
    public PaymentsResource(EnrolHQHttpClient http) : base(http) { }

    /// <summary>Retrieves order lines for a student profile, optionally filtered by payment kind.</summary>
    /// <param name="studentProfileId">The student profile UUID.</param>
    /// <param name="paymentKind">Optional payment kind filter (e.g. "enrolment", "re-enrolment").</param>
    public Task<JsonElement> OrderLinesAsync(string studentProfileId, string? paymentKind = null,
        CancellationToken ct = default)
    {
        var queryParams = new Dictionary<string, string?> { ["student_profile"] = studentProfileId };
        if (paymentKind is not null)
            queryParams["payment_kind"] = paymentKind;
        return Http.GetAsync<JsonElement>("payment/order-lines/", queryParams, ct);
    }

    /// <summary>Batch-updates order lines for a student profile.</summary>
    /// <param name="studentProfileId">The student profile UUID.</param>
    /// <param name="paymentKind">The payment kind (e.g. "enrolment", "re-enrolment").</param>
    /// <param name="payingParentId">The paying parent UUID.</param>
    /// <param name="data">Request body — see the EnrolHQ API docs for the expected schema.</param>
    public async Task<JsonElement> BatchUpdateOrderLinesAsync(string studentProfileId, string paymentKind,
        string payingParentId, object data, CancellationToken ct = default)
        => await Http.PostAsync<JsonElement>("payment/order-lines/batch_update_for_profile/", data,
            new Dictionary<string, string?>
            {
                ["student_profile"] = studentProfileId,
                ["payment_kind"] = paymentKind,
                ["paying_parent"] = payingParentId,
            }, ct);
}
