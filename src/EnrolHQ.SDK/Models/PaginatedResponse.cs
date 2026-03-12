using System.Text.Json.Serialization;

namespace EnrolHQ.SDK.Models;

/// <summary>Standard paginated response wrapper from EnrolHQ API.</summary>
public class PaginatedResponse<T>
{
    [JsonPropertyName("count")]
    public int Count { get; init; }

    [JsonPropertyName("next")]
    public string? Next { get; init; }

    [JsonPropertyName("previous")]
    public string? Previous { get; init; }

    [JsonPropertyName("results")]
    public List<T> Results { get; init; } = [];

    public bool HasNext => Next is not null;
}

/// <summary>Count-only response from /count/ endpoints.</summary>
public class CountResponse
{
    [JsonPropertyName("count")]
    public int Count { get; init; }

    [JsonPropertyName("pks_count")]
    public int? PksCount { get; init; }
}

/// <summary>Token refresh response.</summary>
public class TokenRefreshResponse
{
    [JsonPropertyName("access_token")]
    public string? AccessToken { get; init; }
}
