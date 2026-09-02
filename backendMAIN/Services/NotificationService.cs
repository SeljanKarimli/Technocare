using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Driver;

namespace backend.Services;

public sealed class NotificationService
{
    private readonly IMongoCollection<Notification> _notifications;

    public NotificationService(IOptions<MongoDbSettings> mongoDbSettings)
    {
        var client = new MongoClient(mongoDbSettings.Value.ConnectionString);
        var database = client.GetDatabase(mongoDbSettings.Value.DatabaseName);
        _notifications = database.GetCollection<Notification>(mongoDbSettings.Value.NotificationsCollectionName);
    }

    public Task CreateNotificationAsync(CreateNotificationRequest request) =>
        _notifications.InsertOneAsync(new Notification
        {
            UserId = request.TargetUserId,
            Title = request.Title.Trim(),
            Message = request.Message.Trim(),
            Timestamp = DateTime.UtcNow,
            Read = false,
        });

    public async Task<Notification?> CreateSiteUpdateAsync(SiteUpdateEvent siteEvent, CancellationToken cancellationToken)
    {
        var notification = new Notification
        {
            UserId = null,
            SourceEventId = siteEvent.EventId.Trim(),
            Category = siteEvent.Category.Trim(),
            Title = siteEvent.Title.Trim(),
            Message = siteEvent.Message.Trim(),
            Url = string.IsNullOrWhiteSpace(siteEvent.Url) ? null : siteEvent.Url.Trim(),
            Timestamp = siteEvent.OccurredAt == default ? DateTime.UtcNow : siteEvent.OccurredAt.ToUniversalTime(),
            Read = false,
            NextPushAttemptAt = DateTime.UtcNow,
        };
        try
        {
            await _notifications.InsertOneAsync(notification, cancellationToken: cancellationToken);
            return notification;
        }
        catch (MongoWriteException exception) when (exception.WriteError?.Category == ServerErrorCategory.DuplicateKey)
        {
            return null;
        }
    }

    public Task<List<Notification>> GetPublicNotificationsAsync(int limit = 50, CancellationToken cancellationToken = default) =>
        _notifications.Find(item => item.UserId == null)
            .SortByDescending(item => item.Timestamp)
            .Limit(Math.Clamp(limit, 1, 100))
            .ToListAsync(cancellationToken);

    public Task<List<Notification>> GetUserNotificationsAsync(string userId, CancellationToken cancellationToken = default)
    {
        var filter = Builders<Notification>.Filter.Or(
            Builders<Notification>.Filter.Eq(item => item.UserId, userId),
            Builders<Notification>.Filter.Eq(item => item.UserId, null));
        return _notifications.Find(filter).SortByDescending(item => item.Timestamp).Limit(100).ToListAsync(cancellationToken);
    }

    public Task<List<Notification>> GetAllNotificationsAsync(CancellationToken cancellationToken = default) =>
        _notifications.Find(_ => true).SortByDescending(item => item.Timestamp).Limit(500).ToListAsync(cancellationToken);

    public async Task<bool> MarkNotificationAsReadAsync(string notificationId, string userId)
    {
        // Broadcast read state belongs to each device and is stored locally by Flutter.
        var filter = Builders<Notification>.Filter.And(
            Builders<Notification>.Filter.Eq(item => item.Id, notificationId),
            Builders<Notification>.Filter.Eq(item => item.UserId, userId));
        var result = await _notifications.UpdateOneAsync(filter, Builders<Notification>.Update.Set(item => item.Read, true));
        return result.ModifiedCount > 0;
    }

    public async Task<Notification?> GetPendingPushAsync(CancellationToken cancellationToken) =>
        await _notifications.Find(item =>
                item.SourceEventId != null &&
                item.PushSentAt == null &&
                item.PushAttempts < 8 &&
                item.NextPushAttemptAt <= DateTime.UtcNow)
            .SortBy(item => item.Timestamp)
            .FirstOrDefaultAsync(cancellationToken);

    public Task MarkPushSentAsync(string id, CancellationToken cancellationToken) =>
        _notifications.UpdateOneAsync(
            item => item.Id == id,
            Builders<Notification>.Update
                .Set(item => item.PushSentAt, DateTime.UtcNow)
                .Unset(item => item.PushLastErrorType),
            cancellationToken: cancellationToken);

    public Task MarkPushFailedAsync(Notification notification, Exception exception, CancellationToken cancellationToken)
    {
        var attempts = notification.PushAttempts + 1;
        var delay = TimeSpan.FromMinutes(Math.Min(60, Math.Pow(2, Math.Min(attempts, 6))));
        return _notifications.UpdateOneAsync(
            item => item.Id == notification.Id,
            Builders<Notification>.Update
                .Set(item => item.PushAttempts, attempts)
                .Set(item => item.NextPushAttemptAt, DateTime.UtcNow.Add(delay))
                .Set(item => item.PushLastErrorType, exception.GetType().Name),
            cancellationToken: cancellationToken);
    }

    public async Task<bool> DeleteNotificationAsync(string notificationId)
    {
        var result = await _notifications.DeleteOneAsync(item => item.Id == notificationId);
        return result.DeletedCount > 0;
    }

    public async Task EnsureIndexesAsync(CancellationToken cancellationToken)
    {
        var sourceEvent = new CreateIndexModel<Notification>(
            Builders<Notification>.IndexKeys.Ascending(item => item.SourceEventId),
            new CreateIndexOptions<Notification>
            {
                Name = "ux_notification_source_event",
                Unique = true,
                PartialFilterExpression = new BsonDocument(
                    "sourceEventId",
                    new BsonDocument("$type", "string")),
            });
        var publicTimeline = new CreateIndexModel<Notification>(
            Builders<Notification>.IndexKeys.Ascending(item => item.UserId).Descending(item => item.Timestamp),
            new CreateIndexOptions<Notification> { Name = "ix_notification_user_timestamp" });
        var pendingPush = new CreateIndexModel<Notification>(
            Builders<Notification>.IndexKeys.Ascending(item => item.PushSentAt).Ascending(item => item.NextPushAttemptAt),
            new CreateIndexOptions<Notification> { Name = "ix_notification_pending_push" });
        await _notifications.Indexes.CreateManyAsync([sourceEvent, publicTimeline, pendingPush], cancellationToken);
    }
}
