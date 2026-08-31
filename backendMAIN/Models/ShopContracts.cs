using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace backend.Models;

public sealed class HomeContentResponse
{
    public int SchemaVersion { get; set; } = 1;
    public DateTimeOffset UpdatedAt { get; set; }
    public string SourceUrl { get; set; } = string.Empty;
    public List<HomeSectionDto> Sections { get; set; } = [];
}

public sealed class HomeSectionDto
{
    public string Id { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public int Order { get; set; }
    public string Eyebrow { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public List<string> Images { get; set; } = [];
    public List<HomeLinkDto> Links { get; set; } = [];
    public List<HomeMetricDto> Metrics { get; set; } = [];
    public List<JsonElement> Items { get; set; } = [];
}

public sealed class HomeLinkDto
{
    public string Label { get; set; } = string.Empty;
    public string Url { get; set; } = string.Empty;
}

public sealed class HomeMetricDto
{
    public string Value { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
}

public sealed class SiteProjectDto
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string ImageUrl { get; set; } = string.Empty;
    public List<string> Images { get; set; } = [];
    public string Url { get; set; } = string.Empty;
    public DateTimeOffset? UpdatedAt { get; set; }
}

public sealed class PagedSiteProjectsResponse
{
    public List<SiteProjectDto> Items { get; set; } = [];
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int Total { get; set; }
    public int TotalPages { get; set; }
}

public sealed class SiteContentItemDto
{
    public long Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Summary { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public string ImageUrl { get; set; } = string.Empty;
    public List<string> Images { get; set; } = [];
    public string Url { get; set; } = string.Empty;
    public DateTimeOffset? UpdatedAt { get; set; }
}

public sealed class SiteContentCollectionResponse
{
    public int SchemaVersion { get; set; } = 1;
    public DateTimeOffset? UpdatedAt { get; set; }
    public string SourceUrl { get; set; } = string.Empty;
    public List<SiteContentItemDto> Items { get; set; } = [];
}

public sealed class ShopProductDto
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public string Sku { get; set; } = string.Empty;
    public string Brand { get; set; } = string.Empty;
    public List<ShopTaxonomyDto> Categories { get; set; } = [];
    public string ShortDescription { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public List<string> Images { get; set; } = [];
    public decimal? Price { get; set; }
    public decimal? RegularPrice { get; set; }
    public decimal? SalePrice { get; set; }
    public string CurrencyCode { get; set; } = "AZN";
    public string CurrencySymbol { get; set; } = "₼";
    public bool OnSale { get; set; }
    public bool InStock { get; set; }
    public string StockStatus { get; set; } = string.Empty;
    public bool Purchasable { get; set; }
    public string Permalink { get; set; } = string.Empty;
}

public sealed class ShopTaxonomyDto
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public long ParentId { get; set; }
    public int Count { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
}

public sealed class ShopFacetDto
{
    public List<ShopTaxonomyDto> Categories { get; set; } = [];
    public List<ShopTaxonomyDto> Brands { get; set; } = [];
    public decimal? MinPrice { get; set; }
    public decimal? MaxPrice { get; set; }
    public int InStockCount { get; set; }
}

public sealed class PagedShopProductsResponse
{
    public List<ShopProductDto> Items { get; set; } = [];
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int Total { get; set; }
    public int TotalPages { get; set; }
    public ShopFacetDto Facets { get; set; } = new();
}

public sealed class ShopTaxonomyResponse
{
    public List<ShopTaxonomyDto> Items { get; set; } = [];
}

public sealed class AddShopCartItemRequest
{
    [Range(1, long.MaxValue)]
    public long ProductId { get; set; }

    [Range(1, 99)]
    public int Quantity { get; set; } = 1;
}

public sealed class UpdateShopCartItemRequest
{
    [Range(1, 99)]
    public int Quantity { get; set; }
}

public sealed class ShopCartItemDto
{
    public long ProductId { get; set; }
    public int Quantity { get; set; }
    public ShopProductDto Product { get; set; } = new();
    public decimal LineTotal { get; set; }
}

public sealed class ShopCartDto
{
    public List<ShopCartItemDto> Items { get; set; } = [];
    public int ItemCount { get; set; }
    public decimal Subtotal { get; set; }
    public string CurrencyCode { get; set; } = "AZN";
    public string CurrencySymbol { get; set; } = "₼";
}

public sealed class CheckoutSessionResponse
{
    public string CheckoutUrl { get; set; } = string.Empty;
    public DateTimeOffset ExpiresAt { get; set; }
}

public sealed class ShopOrderItemDto
{
    public long ProductId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal Total { get; set; }
}

public sealed class ShopOrderDto
{
    public long Id { get; set; }
    public string Number { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTimeOffset? CreatedAt { get; set; }
    public string CurrencyCode { get; set; } = "AZN";
    public decimal Total { get; set; }
    public List<ShopOrderItemDto> Items { get; set; } = [];
}

public sealed class PagedShopOrdersResponse
{
    public List<ShopOrderDto> Items { get; set; } = [];
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int Total { get; set; }
    public int TotalPages { get; set; }
}

internal sealed class WordPressCheckoutRequest
{
    public string AppUserId { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public List<WordPressCheckoutItem> Items { get; set; } = [];
}

internal sealed class WordPressCheckoutItem
{
    public long ProductId { get; set; }
    public int Quantity { get; set; }
}

internal sealed class WordPressOrderRequest
{
    public string AppUserId { get; set; } = string.Empty;
    public int Page { get; set; }
}
