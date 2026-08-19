// Models/Cart.cs
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System.Collections.Generic;
namespace backend.Models;
public class CartItem
{
    [BsonElement("productId")]
    [BsonRepresentation(BsonType.ObjectId)]
    public string ProductId { get; set; } = null!;

    [BsonElement("productName")] // Denormalized for easier display
    public string ProductName { get; set; } = null!;

    [BsonElement("price")]
    [BsonRepresentation(BsonType.Decimal128)]
    public decimal Price { get; set; }

    [BsonElement("quantity")]
    public int Quantity { get; set; }

    [BsonElement("imageUrl")] // Denormalized for easier display
    public string ImageUrl { get; set; } = null!;
}

public class Cart
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("items")]
    public List<CartItem> Items { get; set; } = new List<CartItem>();
}

// DTO for adding/updating cart items
public class AddToCartRequest
{
    public string ProductId { get; set; } = null!;
    public int Quantity { get; set; }

    // NEW – denormalized product data:
    public string ProductName { get; set; } = null!;
    public decimal Price { get; set; }
    public string ImageUrl { get; set; } = null!;
}


public class UpdateCartItemRequest
{
    public int Quantity { get; set; }
}
