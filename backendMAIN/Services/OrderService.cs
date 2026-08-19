// Services/OrderService.cs
using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Driver;

namespace backend.Services
{
    public class OrderService
    {
        private readonly IMongoCollection<Order> _orders;
        private readonly CartService _cartService;

        public OrderService(IOptions<MongoDbSettings> mongoDbSettings, CartService cartService)
        {
            var client = new MongoClient(mongoDbSettings.Value.ConnectionString);
            var database = client.GetDatabase(mongoDbSettings.Value.DatabaseName);

            _orders = database.GetCollection<Order>(mongoDbSettings.Value.OrdersCollectionName);
            _cartService = cartService;
        }

        private static bool IsValidObjectId(string? id) => ObjectId.TryParse(id, out _);

        // Controller calls this overload
        public async Task<Order?> CreateOrderFromCartAsync(string userId, CreateOrderRequest request)
            => await CreateOrderFromCartAsync(userId, request, customerEmail: null);

        // Controller calls this overload with customerEmail sometimes; we accept it, but we don't need it.
        public async Task<Order?> CreateOrderFromCartAsync(string userId, CreateOrderRequest request, string? customerEmail)
        {
            if (request == null) throw new Exception("Request is null.");
            if (string.IsNullOrWhiteSpace(userId) || !IsValidObjectId(userId))
                throw new Exception("Invalid userId.");
            if (string.IsNullOrWhiteSpace(request.CartId) || !IsValidObjectId(request.CartId))
                throw new Exception("Invalid cartId.");

            // ✅ NEW DESIGN: load cart by CartId
            var cart = await _cartService.GetCartByIdAsync(request.CartId);
            if (cart == null || cart.Items == null || cart.Items.Count == 0)
                throw new Exception("Cart is empty.");

            var order = new Order
            {
                UserId = userId,
                CartId = request.CartId,
                OrderDate = request.OrderDate == default ? DateTime.UtcNow : request.OrderDate,
                Status = string.IsNullOrWhiteSpace(request.Status) ? "Pending" : request.Status.Trim(),

                // Order : Cart -> Items is inherited from Cart
                Items = cart.Items
            };

            await _orders.InsertOneAsync(order);

            // Optional but usually expected: clear cart after order
            await _cartService.ClearCartAsync(request.CartId);

            return order;
        }

        // READ
        public async Task<List<Order>> GetOrdersByUserIdAsync(string userId)
        {
            if (!IsValidObjectId(userId)) return new List<Order>();

            return await _orders.Find(o => o.UserId == userId)
                                .SortByDescending(o => o.OrderDate)
                                .ToListAsync();
        }

        public async Task<Order?> GetOrderByIdAsync(string id)
        {
            if (!IsValidObjectId(id)) return null;

            // Id exists via Cart.Id (base class)
            return await _orders.Find(o => o.Id == id).FirstOrDefaultAsync();
        }

        public async Task<List<Order>> GetAllOrdersAsync()
        {
            return await _orders.Find(_ => true)
                                .SortByDescending(o => o.OrderDate)
                                .ToListAsync();
        }

        // UPDATE
        public async Task<bool> UpdateOrderStatusAsync(string id, UpdateOrderStatusRequest request)
        {
            if (!IsValidObjectId(id)) return false;
            if (request == null || string.IsNullOrWhiteSpace(request.Status)) return false;

            var result = await _orders.UpdateOneAsync(
                o => o.Id == id,
                Builders<Order>.Update.Set(o => o.Status, request.Status.Trim())
            );

            return result.MatchedCount > 0;
        }

        // DELETE
        public async Task<bool> DeleteOrderAsync(string id)
        {
            if (!IsValidObjectId(id)) return false;

            var result = await _orders.DeleteOneAsync(o => o.Id == id);
            return result.DeletedCount > 0;
        }
    }
}
