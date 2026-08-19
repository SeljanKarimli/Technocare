using backend.Models;
using MongoDB.Driver;

namespace backend.Services
{
    public class CategoryService
    {
        private readonly IMongoCollection<Category> _categories;

        public CategoryService(MongoDbContext context)
        {
            _categories = context.Categories;
        }

        public async Task<List<Category>> GetAsync()
        {
            return await _categories.Find(_ => true).ToListAsync();
        }

        public async Task<Category?> GetByIdAsync(string id)
        {
            return await _categories.Find(c => c.Id == id).FirstOrDefaultAsync();
        }

        public async Task<Category> CreateAsync(Category category)
        {
            await _categories.InsertOneAsync(category);
            return category;
        }

        public async Task<bool> UpdateAsync(string id, Category updatedCategory)
        {
            var result = await _categories.ReplaceOneAsync(c => c.Id == id, updatedCategory);
            return result.ModifiedCount > 0;
        }

        public async Task<bool> DeleteAsync(string id)
        {
            var result = await _categories.DeleteOneAsync(c => c.Id == id);
            return result.DeletedCount > 0;
        }
    }
}