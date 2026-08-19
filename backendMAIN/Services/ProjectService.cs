using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Driver;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace backend.Services
{
    public class ProjectService
    {
        private readonly IMongoCollection<Project> _projectsCollection;

        public ProjectService(IOptions<MongoDbSettings> mongoDbSettings)
        {
            var mongoClient = new MongoClient(mongoDbSettings.Value.ConnectionString);
            var mongoDatabase = mongoClient.GetDatabase(mongoDbSettings.Value.DatabaseName);
            _projectsCollection = mongoDatabase.GetCollection<Project>(mongoDbSettings.Value.ProjectsCollectionName);
        }

        // Get all projects with pagination
        public async Task<List<Project>> GetAllAsync() =>
                await _projectsCollection.Find(_ => true).ToListAsync();

        // Get filtered projects
        //public async Task<List<Project>> GetFilteredAsync(string? date = null, string? search = null, int limit = 10, int page = 1)
        //{
        //    var filterBuilder = Builders<Project>.Filter;
        //    var filter = filterBuilder.Empty;
        //    if (!string.IsNullOrEmpty(search))
        //    {
        //        filter &= filterBuilder.Or(
        //            filterBuilder.Regex(p => p.Name, new BsonRegularExpression(search, "i")),
        //            filterBuilder.Regex(p => p.Description, new BsonRegularExpression(search, "i")),
        //            filterBuilder.Regex(p => p.Content, new BsonRegularExpression(search, "i"))
        //        );
        //    }

        //    return await _projectsCollection.Find(filter)
        //        .Skip((page - 1) * limit)
        //        .Limit(limit)
        //        .ToListAsync();
        //}

        // Get single project by ID
        public async Task<Project?> GetByIdAsync(string id) =>
            await _projectsCollection.Find(p => p.Id == id).FirstOrDefaultAsync();

        // Create project
        public async Task<Project> CreateAsync(ProjectCreateRequest req)
        {
            var project = new Project
            {
                Id = null, // Mongo will generate ObjectId
                Name = req.Name,
                Description = req.Description,
                ImageUrl = req.ImageUrl,
                Images = req.Images,
                Content = req.Content
            };

            await _projectsCollection.InsertOneAsync(project);
            return project;
        }


        // Update project with ProjectUpdateRequest
        public async Task<bool> UpdateAsync(string id, ProjectUpdateRequest request)
        {
            //var existing = await GetByIdAsync(id);
            //if (existing == null) return false;

            var update = Builders<Project>.Update
                .Set(p => p.Name, request.Name)
                .Set(p => p.Description, request.Description)
                .Set(p => p.Content, request.Content)
                .Set(p => p.ImageUrl, request.ImageUrl)
                .Set(p => p.Images, request.Images);

            var result = await _projectsCollection.UpdateOneAsync(p => p.Id == id, update);
            return result.ModifiedCount > 0;
        }

        // Delete project
        public async Task<bool> DeleteAsync(string id)
        {
            var result = await _projectsCollection.DeleteOneAsync(p => p.Id == id);
            return result.DeletedCount > 0;
        }
    }
}