// Services/NotificationService.cs
using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Driver;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace backend.Services
{
    public class NotificationService
    {
        private readonly IMongoCollection<Notification> _notificationsCollection;
        private readonly IMongoCollection<User> _usersCollection; 

        public NotificationService(IOptions<MongoDbSettings> mongoDbSettings)
        {
            var mongoClient = new MongoClient(mongoDbSettings.Value.ConnectionString);
            var mongoDatabase = mongoClient.GetDatabase(mongoDbSettings.Value.DatabaseName);
            _notificationsCollection = mongoDatabase.GetCollection<Notification>(mongoDbSettings.Value.NotificationsCollectionName);
            _usersCollection = mongoDatabase.GetCollection<User>(mongoDbSettings.Value.UsersCollectionName);
        }

        public async Task CreateNotificationAsync(CreateNotificationRequest request)
        {
            var newNotification = new Notification
            {
                UserId = request.TargetUserId,
                Title = request.Title,
                Message = request.Message,
                Timestamp = DateTime.UtcNow,
                Read = false 
            };
            await _notificationsCollection.InsertOneAsync(newNotification);
        }

        public async Task<List<Notification>> GetUserNotificationsAsync(string userId)
        {
            var filter = Builders<Notification>.Filter.Or(
                Builders<Notification>.Filter.Eq(n => n.UserId, userId),
                Builders<Notification>.Filter.Eq(n => n.UserId, null) 
            );

            return await _notificationsCollection.Find(filter)
                                                 .SortByDescending(n => n.Timestamp)
                                                 .ToListAsync();
        }

        public async Task<bool> MarkNotificationAsReadAsync(string notificationId, string userId)
        {
            var filter = Builders<Notification>.Filter.And(
                Builders<Notification>.Filter.Eq(n => n.Id, notificationId),
                Builders<Notification>.Filter.Or( 
                    Builders<Notification>.Filter.Eq(n => n.UserId, userId),
                    Builders<Notification>.Filter.Eq(n => n.UserId, null)
                )
            );
            var update = Builders<Notification>.Update.Set(n => n.Read, true);
            var result = await _notificationsCollection.UpdateOneAsync(filter, update);
            return result.ModifiedCount > 0;
        }

        public async Task<bool> DeleteNotificationAsync(string notificationId)
        {
            var result = await _notificationsCollection.DeleteOneAsync(n => n.Id == notificationId);
            return result.DeletedCount > 0;
        }
    }
}
