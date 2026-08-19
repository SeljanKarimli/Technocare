// Models/Project.cs
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using System.Collections.Generic;

namespace backend.Models;
public class Project
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("name")]
    public string Name { get; set; } = null!;

    [BsonElement("description")]
    public string Description { get; set; } = null!;

    [BsonElement("imageUrl")]
    public string ImageUrl { get; set; } = null!;

    [BsonElement("images")]
    public List<string>? Images { get; set; } = null!;

    [BsonElement("content")]
    public string Content { get; set; } = null!;
}

// DTOs for project management
public class ProjectCreateRequest
{
    //public string? Id { get; set; }
    public string Name { get; set; } = null!;
    public string Description { get; set; } = null!;
    public string ImageUrl { get; set; } = null!;
    public List<string>? Images { get; set; } = null!;
    public string Content { get; set; } = null!;
}

public class ProjectUpdateRequest
{
    public string? Id { get; set; }
    public string Name { get; set; } = null!;
    public string Description { get; set; } = null!;
    public string ImageUrl { get; set; } = null!;
    public List<string>? Images { get; set; } = null!;
    public string Content { get; set; } = null!;
}