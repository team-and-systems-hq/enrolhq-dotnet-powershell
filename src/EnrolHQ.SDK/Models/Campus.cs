using System.Text.Json.Serialization;

namespace EnrolHQ.SDK.Models;

/// <summary>School campus.</summary>
public class Campus
{
    [JsonPropertyName("id")]
    public string Id { get; init; } = "";

    [JsonPropertyName("name")]
    public string Name { get; init; } = "";

    [JsonPropertyName("slug")]
    public string? Slug { get; init; }

    [JsonPropertyName("registrar_title")]
    public string? RegistrarTitle { get; init; }

    [JsonPropertyName("email")]
    public string? Email { get; init; }

    [JsonPropertyName("telephone")]
    public string? Telephone { get; init; }

    [JsonPropertyName("residential_address")]
    public Address? ResidentialAddress { get; init; }
}

/// <summary>Address object used across multiple models.</summary>
public class Address
{
    [JsonPropertyName("id")]
    public string? Id { get; init; }

    [JsonPropertyName("apartment")]
    public string? Apartment { get; init; }

    [JsonPropertyName("street_address")]
    public string? StreetAddress { get; init; }

    [JsonPropertyName("city")]
    public string? City { get; init; }

    [JsonPropertyName("suburb")]
    public string? Suburb { get; init; }

    [JsonPropertyName("state")]
    public string? State { get; init; }

    [JsonPropertyName("postcode")]
    public string? Postcode { get; init; }

    [JsonPropertyName("country")]
    public string? Country { get; init; }
}
