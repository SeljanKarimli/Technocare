using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace backend.Models;

public sealed class EmailOutboxMessage
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("to")]
    public string To { get; set; } = string.Empty;

    [BsonElement("subject")]
    public string Subject { get; set; } = string.Empty;

    [BsonElement("htmlBody")]
    public string HtmlBody { get; set; } = string.Empty;

    [BsonElement("createdAt")]
    [BsonDateTimeOptions(Kind = DateTimeKind.Utc)]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [BsonElement("nextAttemptAt")]
    [BsonDateTimeOptions(Kind = DateTimeKind.Utc)]
    public DateTime NextAttemptAt { get; set; } = DateTime.UtcNow;

    [BsonElement("attempts")]
    public int Attempts { get; set; }

    [BsonElement("sentAt")]
    [BsonIgnoreIfNull]
    [BsonDateTimeOptions(Kind = DateTimeKind.Utc)]
    public DateTime? SentAt { get; set; }

    [BsonElement("lastErrorType")]
    [BsonIgnoreIfNull]
    public string? LastErrorType { get; set; }
}
