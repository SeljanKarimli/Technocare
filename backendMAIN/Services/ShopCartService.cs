using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Driver;

namespace backend.Services;

public sealed class ShopCartService
{
    private readonly IMongoCollection<ShopCart> _carts;
    private readonly ITechnocareSiteClient _siteClient;

    public ShopCartService(IOptions<MongoDbSettings> settings, ITechnocareSiteClient siteClient)
    {
        var client = new MongoClient(settings.Value.ConnectionString);
        var database = client.GetDatabase(settings.Value.DatabaseName);
        _carts = database.GetCollection<ShopCart>(settings.Value.ShopCartsCollectionName);
        _siteClient = siteClient;
    }

    public async Task<ShopCartDto> GetAsync(string userId, CancellationToken cancellationToken)
    {
        var cart = await _carts.Find(item => item.UserId == userId).FirstOrDefaultAsync(cancellationToken);
        return await HydrateAsync(cart?.Items ?? [], cancellationToken);
    }

    public async Task<IReadOnlyList<ShopCartItem>> GetRawItemsAsync(string userId, CancellationToken cancellationToken)
    {
        var cart = await _carts.Find(item => item.UserId == userId).FirstOrDefaultAsync(cancellationToken);
        return cart?.Items ?? [];
    }

    public async Task<ShopCartDto> AddAsync(string userId, long productId, int quantity, CancellationToken cancellationToken)
    {
        var product = await _siteClient.GetProductAsync(productId, cancellationToken);
        if (!product.Purchasable || !product.InStock)
        {
            throw new ShopCartException("Bu məhsul hazırda səbətə əlavə edilə bilməz.");
        }

        var cart = await _carts.Find(item => item.UserId == userId).FirstOrDefaultAsync(cancellationToken)
            ?? new ShopCart { UserId = userId };
        var item = cart.Items.FirstOrDefault(entry => entry.WooProductId == productId);
        if (item is null)
        {
            cart.Items.Add(new ShopCartItem { WooProductId = productId, Quantity = Math.Clamp(quantity, 1, 99) });
        }
        else
        {
            item.Quantity = Math.Clamp(item.Quantity + quantity, 1, 99);
        }
        await SaveAsync(cart, cancellationToken);
        return await HydrateAsync(cart.Items, cancellationToken);
    }

    public async Task<ShopCartDto> UpdateAsync(string userId, long productId, int quantity, CancellationToken cancellationToken)
    {
        var cart = await _carts.Find(item => item.UserId == userId).FirstOrDefaultAsync(cancellationToken)
            ?? throw new ShopCartException("Səbət tapılmadı.");
        var item = cart.Items.FirstOrDefault(entry => entry.WooProductId == productId)
            ?? throw new ShopCartException("Məhsul səbətdə tapılmadı.");
        item.Quantity = Math.Clamp(quantity, 1, 99);
        await SaveAsync(cart, cancellationToken);
        return await HydrateAsync(cart.Items, cancellationToken);
    }

    public async Task<ShopCartDto> RemoveAsync(string userId, long productId, CancellationToken cancellationToken)
    {
        var cart = await _carts.Find(item => item.UserId == userId).FirstOrDefaultAsync(cancellationToken);
        if (cart is null)
        {
            return new ShopCartDto();
        }
        cart.Items.RemoveAll(entry => entry.WooProductId == productId);
        await SaveAsync(cart, cancellationToken);
        return await HydrateAsync(cart.Items, cancellationToken);
    }

    public async Task ClearAsync(string userId, CancellationToken cancellationToken)
    {
        await _carts.DeleteOneAsync(item => item.UserId == userId, cancellationToken);
    }

    private async Task SaveAsync(ShopCart cart, CancellationToken cancellationToken)
    {
        cart.UpdatedAt = DateTime.UtcNow;
        await _carts.ReplaceOneAsync(
            item => item.UserId == cart.UserId,
            cart,
            new ReplaceOptions { IsUpsert = true },
            cancellationToken);
    }

    private async Task<ShopCartDto> HydrateAsync(IEnumerable<ShopCartItem> rawItems, CancellationToken cancellationToken)
    {
        var items = rawItems.ToList();
        if (items.Count == 0)
        {
            return new ShopCartDto();
        }
        var products = await Task.WhenAll(items.Select(item => _siteClient.GetProductAsync(item.WooProductId, cancellationToken)));
        var hydrated = items.Zip(products, (item, product) => new ShopCartItemDto
        {
            ProductId = item.WooProductId,
            Quantity = item.Quantity,
            Product = product,
            LineTotal = (product.Price ?? 0m) * item.Quantity,
        }).ToList();
        return new ShopCartDto
        {
            Items = hydrated,
            ItemCount = hydrated.Sum(item => item.Quantity),
            Subtotal = hydrated.Sum(item => item.LineTotal),
            CurrencyCode = products.FirstOrDefault()?.CurrencyCode ?? "AZN",
            CurrencySymbol = products.FirstOrDefault()?.CurrencySymbol ?? "₼",
        };
    }
}

public sealed class ShopCartException : Exception
{
    public ShopCartException(string message) : base(message)
    {
    }
}
