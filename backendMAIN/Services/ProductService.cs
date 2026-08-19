// Services/ProductService.cs
using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Driver;

namespace backend.Services
{
    public class ProductService
    {
        private readonly IMongoCollection<Product> _products;

        public ProductService(IOptions<MongoDbSettings> mongoDbSettings)
        {
            var client = new MongoClient(mongoDbSettings.Value.ConnectionString);
            var db = client.GetDatabase(mongoDbSettings.Value.DatabaseName);
            _products = db.GetCollection<Product>(mongoDbSettings.Value.ProductsCollectionName);
        }

        // ---------------------------
        // Helpers
        // ---------------------------
        private static bool IsValidObjectId(string? id) => ObjectId.TryParse(id, out _);

        // ---------------------------
        // Read
        // ---------------------------

        public async Task<List<Product>> GetAllAsync(int page = 1, int pageSize = 10)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            return await _products.Find(Builders<Product>.Filter.Empty)
                .Skip((page - 1) * pageSize)
                .Limit(pageSize)
                .ToListAsync();
        }

        public async Task<Product?> GetByIdAsync(string id)
        {
            if (!IsValidObjectId(id)) return null;
            return await _products.Find(p => p.Id == id).FirstOrDefaultAsync();
        }

        /// <summary>
        /// Filter by CategoryId and/or search in Name/Description. Includes pagination.
        /// </summary>
        public async Task<List<Product>> GetFilteredAsync(
            string? categoryId = null,
            string? search = null,
            int page = 1,
            int pageSize = 10)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var fb = Builders<Product>.Filter;
            var filter = fb.Empty;

            if (!string.IsNullOrWhiteSpace(categoryId))
            {
                if (!IsValidObjectId(categoryId))
                    return new List<Product>(); // invalid category id => no results (safe behavior)

                filter &= fb.Eq(p => p.CategoryId, categoryId);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                // Case-insensitive regex on name/description
                var regex = new BsonRegularExpression(search.Trim(), "i");
                filter &= fb.Or(
                    fb.Regex(p => p.Name, regex),
                    fb.Regex(p => p.Description, regex)
                );
            }

            return await _products.Find(filter)
                .Skip((page - 1) * pageSize)
                .Limit(pageSize)
                .ToListAsync();
        }

        // Optional: total count for pagination UI
        public async Task<long> CountFilteredAsync(string? categoryId = null, string? search = null)
        {
            var fb = Builders<Product>.Filter;
            var filter = fb.Empty;

            if (!string.IsNullOrWhiteSpace(categoryId))
            {
                if (!IsValidObjectId(categoryId)) return 0;
                filter &= fb.Eq(p => p.CategoryId, categoryId);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var regex = new BsonRegularExpression(search.Trim(), "i");
                filter &= fb.Or(
                    fb.Regex(p => p.Name, regex),
                    fb.Regex(p => p.Description, regex)
                );
            }

            return await _products.CountDocumentsAsync(filter);
        }

        // ---------------------------
        // Create
        // ---------------------------

        public async Task<Product?> CreateAsync(ProductCreateRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Name)) return null;
            if (string.IsNullOrWhiteSpace(request.Description)) return null;
            if (string.IsNullOrWhiteSpace(request.ImageUrl)) return null;

            // CategoryId is required in Product model; you allowed nullable in request.
            if (string.IsNullOrWhiteSpace(request.CategoryId) || !IsValidObjectId(request.CategoryId))
                return null;

            if (request.Price < 0) return null;
            if (request.Stock < 0) return null;

            var newProduct = new Product
            {
                Name = request.Name.Trim(),
                Description = request.Description.Trim(),
                Price = request.Price,
                ImageUrl = request.ImageUrl.Trim(),
                CategoryId = request.CategoryId,
                Stock = request.Stock
            };

            await _products.InsertOneAsync(newProduct);
            return newProduct;
        }

        // ---------------------------
        // Update
        // ---------------------------

        public async Task<bool> UpdateAsync(string id, ProductUpdateRequest request)
        {
            if (!IsValidObjectId(id)) return false;

            var updates = new List<UpdateDefinition<Product>>();
            var ub = Builders<Product>.Update;

            if (request.Name != null)
                updates.Add(ub.Set(p => p.Name, request.Name.Trim()));

            if (request.Description != null)
                updates.Add(ub.Set(p => p.Description, request.Description.Trim()));

            if (request.Price.HasValue)
            {
                if (request.Price.Value < 0) return false;
                updates.Add(ub.Set(p => p.Price, request.Price.Value));
            }

            if (request.ImageUrl != null)
                updates.Add(ub.Set(p => p.ImageUrl, request.ImageUrl.Trim()));

            if (request.CategoryId != null)
            {
                if (!IsValidObjectId(request.CategoryId)) return false;
                updates.Add(ub.Set(p => p.CategoryId, request.CategoryId));
            }

            if (request.Stock.HasValue)
            {
                if (request.Stock.Value < 0) return false;
                updates.Add(ub.Set(p => p.Stock, request.Stock.Value));
            }

            if (updates.Count == 0) return false; // nothing to update

            var update = ub.Combine(updates);
            var result = await _products.UpdateOneAsync(p => p.Id == id, update);

            // MatchedCount checks existence; ModifiedCount can be 0 if values are identical
            return result.MatchedCount > 0;
        }

        // ---------------------------
        // Delete
        // ---------------------------

        public async Task<bool> DeleteAsync(string id)
        {
            if (!IsValidObjectId(id)) return false;
            var result = await _products.DeleteOneAsync(p => p.Id == id);
            return result.DeletedCount > 0;
        }

        // ---------------------------
        // Stock helpers (optional but useful)
        // ---------------------------

        public async Task<bool> DecreaseStockAsync(string id, int amount)
        {
            if (!IsValidObjectId(id)) return false;
            if (amount <= 0) return false;

            // Atomic: only decrease if stock is enough
            var filter = Builders<Product>.Filter.And(
                Builders<Product>.Filter.Eq(p => p.Id, id),
                Builders<Product>.Filter.Gte(p => p.Stock, amount)
            );

            var update = Builders<Product>.Update.Inc(p => p.Stock, -amount);

            var result = await _products.UpdateOneAsync(filter, update);
            return result.ModifiedCount > 0;
        }
    }
}
