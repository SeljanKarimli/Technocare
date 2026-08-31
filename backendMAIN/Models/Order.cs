// Models/Order.cs
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;
namespace backend.Models;

public class Order : Cart
{
    // REMOVE Id here (Cart already has BsonId Id)

    [BsonElement("userId")]
    [BsonRepresentation(BsonType.ObjectId)]
    public string UserId { get; set; } = null!;

    [BsonElement("orderDate")]
    [BsonDateTimeOptions(Kind = DateTimeKind.Utc)]
    public DateTime OrderDate { get; set; } = DateTime.UtcNow;

    [BsonElement("status")]
    public string Status { get; set; } = "Pending";

    [BsonElement("cartId")]
    [BsonRepresentation(BsonType.ObjectId)]
    public string CartId { get; set; } = null!;
}


// DTO for creating an order
public class CreateOrderRequest
{
    [JsonPropertyName("userId")]
    public string UserId { get; set; } = default!;

    [JsonPropertyName("orderDate")]
    public DateTime OrderDate { get; set; } = DateTime.UtcNow;

    [JsonPropertyName("status")]
    public string Status { get; set; } = "Pending"; // e.g., "Pending", "Processing", "Shipped", "Delivered", "Cancelled"

    [JsonPropertyName("cartId")]
    public string CartId { get; set; } = null!;
}

// DTO for updating order status (for admin)
public class UpdateOrderStatusRequest
{
    public string Status { get; set; } = null!;
}
