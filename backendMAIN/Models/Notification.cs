// Models/Notification.cs
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System;

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
    }

    // DTO for sending a new notification from admin
    public class CreateNotificationRequest
    {
        public string Title { get; set; } = null!;
        public string Message { get; set; } = null!;
        public string? TargetUserId { get; set; } // Optional: if sending to a specific user
    }
}
