using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Driver;
using System.Runtime.CompilerServices;

namespace backend.Services;

public class CartService
{
    private readonly IMongoCollection<Product> _productsCollection;
    private readonly IMongoCollection<Cart> _cartsCollection;

    public CartService(IOptions<MongoDbSettings> mongoSettings)
    {
        var client = new MongoClient(mongoSettings.Value.ConnectionString);
        var database = client.GetDatabase(mongoSettings.Value.DatabaseName);

        _cartsCollection = database.GetCollection<Cart>("Carts");
        _productsCollection = database.GetCollection<Product>("Products"); // ✅ MƏHZ BU
    }

    public async Task<Cart?> GetCartByIdAsync(string cartId)
    {
        var cart = await _cartsCollection
            .Find(c => c.Id == cartId)
            .FirstOrDefaultAsync();

        if (cart == null)
            return null;

        await SyncCartItemsWithProductsAsync(cart);

        // İstəsən bu xətti əlavə edib, denormalizə məlumatı DB-də də yeniləyə bilərsən:
        await _cartsCollection.ReplaceOneAsync(c => c.Id == cartId, cart);

        return cart;
    }
    private async Task SyncCartItemsWithProductsAsync(Cart cart)
    {
        if (cart.Items == null || !cart.Items.Any())
            return;

        var productIds = cart.Items
            .Select(i => i.ProductId)
            .Distinct()
            .ToList();

        var products = await _productsCollection
            .Find(p => productIds.Contains(p.Id!))
            .ToListAsync();

        var productDict = products.ToDictionary(p => p.Id!);

        foreach (var item in cart.Items)
        {
            if (!productDict.TryGetValue(item.ProductId, out var product))
                continue; // ❗ SİLMİRİK

            item.ProductName = product.Name;
            item.Price = product.Price;
            item.ImageUrl = product.ImageUrl;
        }
    }

    public async Task<Cart> AddOrUpdateItemAsync(string cartId, AddToCartRequest request)
    {
        var cart = await GetCartByIdAsync(cartId);

        if (cart == null)
        {
            cart = new Cart
            {
                Id = cartId,
                Items = new List<CartItem>()
            };
        }

        var item = cart.Items.FirstOrDefault(i => i.ProductId == request.ProductId);

        if (item == null)
        {
            cart.Items.Add(new CartItem
            {
                ProductId = request.ProductId,
                ProductName = request.ProductName,
                Price = request.Price,
                Quantity = request.Quantity,
                ImageUrl = request.ImageUrl
            });
        }
        else
        {
            // artıq cartdadır – təkcə quantity artır, amma məlumatları da sync saxlayırıq
            item.Quantity += request.Quantity;
            item.ProductName = request.ProductName;
            item.Price = request.Price;
            item.ImageUrl = request.ImageUrl;
        }

        await _cartsCollection.ReplaceOneAsync(
            c => c.Id == cartId,
            cart,
            new ReplaceOptions { IsUpsert = true });

        return cart;
    }


    public async Task<Cart?> UpdateItemQuantityAsync(string cartId, string productId, UpdateCartItemRequest request)
    {
        var cart = await GetCartByIdAsync(cartId);
        if (cart == null) return null;

        var item = cart.Items.FirstOrDefault(i => i.ProductId == productId);
        if (item == null) return null;

        item.Quantity = request.Quantity;

        await SyncCartItemsWithProductsAsync(cart);

        await _cartsCollection.ReplaceOneAsync(c => c.Id == cartId, cart);
        return cart;
    }


    public async Task<bool> RemoveItemAsync(string cartId, string productId)
    {
        var cart = await GetCartByIdAsync(cartId);
        if (cart == null) return false;

        cart.Items = cart.Items.Where(i => i.ProductId != productId).ToList();

        await _cartsCollection.ReplaceOneAsync(c => c.Id == cartId, cart);
        return true;
    }

    public async Task<bool> ClearCartAsync(string cartId)
    {
        var cart = await GetCartByIdAsync(cartId);
        if (cart == null) return false;

        cart.Items.Clear();

        await _cartsCollection.ReplaceOneAsync(c => c.Id == cartId, cart);
        return true;
    }
}
