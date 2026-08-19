// Data/MongoDbContext.cs
using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Driver;

namespace backend;

public class MongoDbContext
{
    private readonly IMongoDatabase _database;

    public MongoDbContext(IOptions<MongoDbSettings> settings)
    {
        var client = new MongoClient(settings.Value.ConnectionString);
        _database = client.GetDatabase(settings.Value.DatabaseName);
    }

    public IMongoCollection<User> Users => _database.GetCollection<User>("users");
    public IMongoCollection<Product> Products => _database.GetCollection<Product>("products");
    public IMongoCollection<Cart> Carts => _database.GetCollection<Cart>("carts");
    public IMongoCollection<Order> Orders => _database.GetCollection<Order>("orders");
    public IMongoCollection<ServiceApplication> ServiceApplications => _database.GetCollection<ServiceApplication>("serviceapplications");
    public IMongoCollection<EducationApplication> EducationApplications => _database.GetCollection<EducationApplication>("educationapplications");
    public IMongoCollection<Notification> Notifications => _database.GetCollection<Notification>("notifications");
    public IMongoCollection<Project> Projects => _database.GetCollection<Project>("projects");
    public IMongoCollection<Category> Categories => _database.GetCollection<Category>("categories");
}