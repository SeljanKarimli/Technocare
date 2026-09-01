// Services/ApplicationService.cs
using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
namespace backend.Services;
public class EducationApplicationService
{
    private readonly IMongoCollection<EducationApplication> _educationApplicationsCollection;

    public EducationApplicationService(IOptions<MongoDbSettings> mongoDbSettings)
    {
        var mongoClient = new MongoClient(mongoDbSettings.Value.ConnectionString);
        var mongoDatabase = mongoClient.GetDatabase(mongoDbSettings.Value.DatabaseName);
        _educationApplicationsCollection = mongoDatabase.GetCollection<EducationApplication>(mongoDbSettings.Value.EducationApplicationsCollectionName);
    }

    // Submit a new application
    public async Task<EducationApplication> CreateEducationApplicationAsync(CreateEducationApplicationRequest request)
    {
        var educationapplication = new EducationApplication
        {
            ApplicantName = request.Name.Trim(),
            ApplicantEmail = UserService.NormalizeEmail(request.Email),
            ApplicantPhone = request.Phone.Trim(),
            AppliedFor = request.AppliedFor.Trim(),
            Message = request.Message?.Trim(),
            ApplicationDate = DateTime.UtcNow,
            Status = "Pending" // Initial status
        };
        await _educationApplicationsCollection.InsertOneAsync(educationapplication);
        return educationapplication;
    }

    // Get all applications (for admin)
    public async Task<List<EducationApplication>> GetAllEducationApplicationsAsync() =>
        await _educationApplicationsCollection.Find(_ => true).ToListAsync();

    // Get a single application by ID (for admin)
    public async Task<EducationApplication?> GetEducationApplicationByIdAsync(string id) =>
        await _educationApplicationsCollection.Find(a => a.Id == id).FirstOrDefaultAsync();

    // Update application status (for admin)
    public async Task<bool> UpdateEducationApplicationStatusAsync(string id, string newStatus)
    {
        var educationApplication = await _educationApplicationsCollection.Find(a => a.Id == id).FirstOrDefaultAsync();
        if (educationApplication == null) return false;

        var update = Builders<EducationApplication>.Update.Set(a => a.Status, newStatus);
        var result = await _educationApplicationsCollection.UpdateOneAsync(a => a.Id == id, update);
        return result.ModifiedCount > 0;
    }

    // Delete an application (for admin)
    public async Task<bool> DeleteEducationApplicationAsync(string id)
    {
        var result = await _educationApplicationsCollection.DeleteOneAsync(a => a.Id == id);
        return result.DeletedCount > 0;
    }
}
