using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Driver;

namespace backend.Services;

public sealed class ShopCartIndexInitializer : IHostedService
{
    private readonly IOptions<MongoDbSettings> _settings;

    public ShopCartIndexInitializer(IOptions<MongoDbSettings> settings)
    {
        _settings = settings;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        var client = new MongoClient(_settings.Value.ConnectionString);
        var database = client.GetDatabase(_settings.Value.DatabaseName);
        var carts = database.GetCollection<ShopCart>(_settings.Value.ShopCartsCollectionName);
        var model = new CreateIndexModel<ShopCart>(
            Builders<ShopCart>.IndexKeys.Ascending(cart => cart.UserId),
            new CreateIndexOptions { Unique = true, Name = "ux_shop_cart_user" });
        await carts.Indexes.CreateOneAsync(model, cancellationToken: cancellationToken);
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
