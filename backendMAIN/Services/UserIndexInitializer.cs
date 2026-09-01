using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Driver;

namespace backend.Services;

public sealed class UserIndexInitializer : IHostedService
{
    private readonly IMongoCollection<User> _users;

    public UserIndexInitializer(IOptions<MongoDbSettings> settings)
    {
        var client = new MongoClient(settings.Value.ConnectionString);
        var database = client.GetDatabase(settings.Value.DatabaseName);
        _users = database.GetCollection<User>(settings.Value.UsersCollectionName);
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        var model = new CreateIndexModel<User>(
            Builders<User>.IndexKeys.Ascending(user => user.NormalizedEmail),
            new CreateIndexOptions<User>
            {
                Unique = true,
                Name = "ux_user_normalized_email",
                PartialFilterExpression = new BsonDocument("normalizedEmail", new BsonDocument("$type", "string")),
            });
        await _users.Indexes.CreateOneAsync(model, cancellationToken: cancellationToken);
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
