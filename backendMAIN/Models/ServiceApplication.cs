// Models/ServiceApplication.cs
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System;
using System.Text.Json.Serialization; // Added for JsonPropertyName
using System.ComponentModel.DataAnnotations; // Added for validation attributes

namespace backend.Models;

/// <summary>
/// Represents a service application submitted by a user.
/// </summary>
public class ServiceApplication
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    [JsonPropertyName("id")] // Explicitly map to 'id' in JSON
    public string? Id { get; set; }

    [BsonElement("applicantName")]
    [JsonPropertyName("applicantName")] // Explicitly map to 'applicantName' in JSON
    public string ApplicantName { get; set; } = null!;

    [BsonElement("applicantEmail")]
    [JsonPropertyName("applicantEmail")] // Explicitly map to 'applicantEmail' in JSON
    public string ApplicantEmail { get; set; } = null!;

    [BsonElement("applicantPhone")]
    [JsonPropertyName("applicantPhone")] // Explicitly map to 'applicantPhone' in JSON
    public string ApplicantPhone { get; set; } = null!;

    [BsonElement("appliedFor")] // Represents the main service category
    [JsonPropertyName("appliedFor")] // Explicitly map to 'appliedFor' in JSON
    public string AppliedFor { get; set; } = null!;

    [BsonElement("appliedSubService")] // Represents the sub-service selected
    [JsonPropertyName("appliedSubService")]
    public string? AppliedSubService { get; set; }

    [BsonElement("message")]
    [JsonPropertyName("message")] // Explicitly map to 'message' in JSON
    public string? Message { get; set; } // Short message from the applicant

    [BsonElement("applicationDate")]
    [BsonDateTimeOptions(Kind = DateTimeKind.Utc)]
    [JsonPropertyName("applicationDate")] // Explicitly map to 'applicationDate' in JSON
    public DateTime ApplicationDate { get; set; } = DateTime.UtcNow;

    [BsonElement("status")]
    [JsonPropertyName("status")] // Explicitly map to 'status' in JSON
    public string Status { get; set; } = "Pending"; // e.g., "Pending", "Reviewed", "Approved", "Rejected"
}

/// <summary>
/// DTO for submitting a new service application.
/// </summary>
public class CreateServiceApplicationRequest
{
    [Required]
    public string Name { get; set; } = null!;

    [Required]
    public string Email { get; set; } = null!;

    [Required]
    public string Phone { get; set; } = null!;

    [Required]
    public string AppliedFor { get; set; } = null!;

    public string? AppliedSubService { get; set; }

    public string? Message { get; set; }
}
