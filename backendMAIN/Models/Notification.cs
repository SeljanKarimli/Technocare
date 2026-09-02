// Models/Notification.cs
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace backend.Models
{
    public class Notification
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string? Id { get; set; }

        [BsonElement("userId")]
        public string? UserId { get; set; } // Nullable if it's a general notification to all users

        [BsonElement("title")]
        public string Title { get; set; } = null!;

        [BsonElement("message")]
        public string Message { get; set; } = null!;

        [BsonElement("timestamp")]
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;

        [BsonElement("read")]
        public bool Read { get; set; } = false; // For user-specific notifications

        [BsonElement("sourceEventId")]
        [BsonIgnoreIfNull]
        public string? SourceEventId { get; set; }

        [BsonElement("category")]
        [BsonIgnoreIfNull]
        public string? Category { get; set; }

        [BsonElement("url")]
        [BsonIgnoreIfNull]
        public string? Url { get; set; }

        [BsonElement("pushSentAt")]
        [BsonIgnoreIfNull]
        [JsonIgnore]
        public DateTime? PushSentAt { get; set; }

        [BsonElement("pushAttempts")]
        [JsonIgnore]
        public int PushAttempts { get; set; }

        [BsonElement("nextPushAttemptAt")]
        [JsonIgnore]
        public DateTime NextPushAttemptAt { get; set; } = DateTime.UtcNow;

        [BsonElement("pushLastErrorType")]
        [BsonIgnoreIfNull]
        [JsonIgnore]
        public string? PushLastErrorType { get; set; }

        [BsonIgnore]
        public bool IsBroadcast => string.IsNullOrWhiteSpace(UserId);
    }

    // DTO for sending a new notification from admin
    public class CreateNotificationRequest
    {
        public string Title { get; set; } = null!;
        public string Message { get; set; } = null!;
        public string? TargetUserId { get; set; } // Optional: if sending to a specific user
    }

    public sealed class SiteUpdateEvent
    {
        [Required, StringLength(128, MinimumLength = 12)]
        public string EventId { get; set; } = null!;

        [Required, StringLength(40)]
        public string Category { get; set; } = null!;

        [Required, StringLength(160)]
        public string Title { get; set; } = null!;

        [Required, StringLength(600)]
        public string Message { get; set; } = null!;

        [Url, StringLength(1000)]
        public string? Url { get; set; }

        public DateTime OccurredAt { get; set; }
    }
}
