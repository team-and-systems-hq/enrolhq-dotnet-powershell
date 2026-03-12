using System.Text.Json;
using EnrolHQ.SDK.Http;

namespace EnrolHQ.SDK.Resources;

/// <summary>Manage order lines and payments.</summary>
public class PaymentsResource : BaseResource
{
    public PaymentsResource(EnrolHQHttpClient http) : base(http) { }

    public Task<JsonElement> OrderLinesAsync(string studentProfileId, string? paymentKind = null,
        CancellationToken ct = default)
    {
        var queryParams = new Dictionary<string, string?> { ["student_profile"] = studentProfileId };
        if (paymentKind is not null)
            queryParams["payment_kind"] = paymentKind;
        return Http.GetAsync<JsonElement>("payment/order-lines/", queryParams, ct);
    }

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
