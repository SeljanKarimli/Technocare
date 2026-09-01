// Services/ServiceApplicationService.cs
using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
namespace backend.Services;
public class ServiceApplicationService
{
    private readonly IMongoCollection<ServiceApplication> _serviceApplicationsCollection;

    public ServiceApplicationService(IOptions<MongoDbSettings> mongoDbSettings)
    {
        var mongoClient = new MongoClient(mongoDbSettings.Value.ConnectionString);
        var mongoDatabase = mongoClient.GetDatabase(mongoDbSettings.Value.DatabaseName);
        _serviceApplicationsCollection = mongoDatabase.GetCollection<ServiceApplication>(mongoDbSettings.Value.ServiceApplicationsCollectionName);
    }

    // Submit a new service application
    public async Task<ServiceApplication> CreateServiceApplicationAsync(CreateServiceApplicationRequest request)
    {
        var serviceapplication = new ServiceApplication
        {
            ApplicantName = request.Name.Trim(),
            ApplicantEmail = UserService.NormalizeEmail(request.Email),
            ApplicantPhone = request.Phone.Trim(),
            AppliedFor = request.AppliedFor.Trim(),
            AppliedSubService = request.AppliedSubService?.Trim(),
            Message = request.Message?.Trim(),
            ApplicationDate = DateTime.UtcNow,
            Status = "Pending" // Initial status
        };
        await _serviceApplicationsCollection.InsertOneAsync(serviceapplication);
        return serviceapplication;
    }

    // Get all service applications (for admin)
    public async Task<List<ServiceApplication>> GetAllServiceApplicationsAsync() =>
        await _serviceApplicationsCollection.Find(_ => true).ToListAsync();

    // Get a single service application by ID (for admin)
    public async Task<ServiceApplication?> GetServiceApplicationByIdAsync(string id) =>
        await _serviceApplicationsCollection.Find(a => a.Id == id).FirstOrDefaultAsync();

    // Update service application status (for admin)
    public async Task<bool> UpdateServiceApplicationStatusAsync(string id, string newStatus)
    {
        var serviceapplication = await _serviceApplicationsCollection.Find(a => a.Id == id).FirstOrDefaultAsync();
        if (serviceapplication == null) return false;

        var update = Builders<ServiceApplication>.Update.Set(a => a.Status, newStatus);
        var result = await _serviceApplicationsCollection.UpdateOneAsync(a => a.Id == id, update);
        return result.ModifiedCount > 0;
    }

    // Delete a service application (for admin)
    public async Task<bool> DeleteServiceApplicationAsync(string id)
    {
        var result = await _serviceApplicationsCollection.DeleteOneAsync(a => a.Id == id);
        return result.DeletedCount > 0;
    }
}
