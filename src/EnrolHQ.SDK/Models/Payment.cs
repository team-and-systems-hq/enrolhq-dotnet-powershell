using System.Text.Json.Serialization;

namespace EnrolHQ.SDK.Models;

/// <summary>Payment record.</summary>
public class Payment
{
    [JsonPropertyName("id")]
    public string Id { get; init; } = "";

    [JsonPropertyName("student_profile")]
    public string? StudentProfile { get; init; }

    [JsonPropertyName("payment_kind")]
    public string? PaymentKind { get; init; }

    [JsonPropertyName("paid_at")]
    public string? PaidAt { get; init; }

    [JsonPropertyName("is_archived")]
    public bool? IsArchived { get; init; }

    [JsonPropertyName("refunded_at")]
    public string? RefundedAt { get; init; }

    [JsonPropertyName("refunded_by")]
    public string? RefundedBy { get; init; }

    [JsonPropertyName("transaction_number")]
    public string? TransactionNumber { get; init; }

    [JsonPropertyName("amount")]
    public string? Amount { get; init; }

    [JsonPropertyName("reference_id")]
    public string? ReferenceId { get; init; }

    [JsonPropertyName("result_text")]
    public string? ResultText { get; init; }

    [JsonPropertyName("summary")]
    public string? Summary { get; init; }

    [JsonPropertyName("created_at")]
    public string? CreatedAt { get; init; }

    [JsonPropertyName("receipt_number")]
    public string? ReceiptNumber { get; init; }

    [JsonPropertyName("gl_code")]
    public string? GlCode { get; init; }

    [JsonPropertyName("gst")]
    public string? Gst { get; init; }

    [JsonPropertyName("surcharge_amount")]
    public string? SurchargeAmount { get; init; }
}
