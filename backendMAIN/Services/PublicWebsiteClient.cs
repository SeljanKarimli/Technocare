using System.Globalization;
using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using backend.Models;
using HtmlAgilityPack;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Caching.Memory;

namespace backend.Services;

public sealed class PublicWebsiteClient(HttpClient http, IMemoryCache cache)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private sealed record Document(JsonElement Data, int Total, int TotalPages, DateTimeOffset LoadedAt);
    private sealed record Markup(string Value, DateTimeOffset LoadedAt);

    private async Task<string> MarkupAsync(string path, CancellationToken ct)
    {
        cache.TryGetValue("markup:" + path, out Markup? cached);
        if (cached is not null && DateTimeOffset.UtcNow - cached.LoadedAt < TimeSpan.FromMinutes(5)) return cached.Value;
        try
        {
            using var response = await http.GetAsync(path, ct);
            response.EnsureSuccessStatusCode();
            var value = await response.Content.ReadAsStringAsync(ct);
            cache.Set("markup:" + path, new Markup(value, DateTimeOffset.UtcNow), new MemoryCacheEntryOptions { Size = 1, AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(24) });
            return value;
        }
        catch (HttpRequestException) when (cached is not null) { return cached.Value; }
        catch (TaskCanceledException) when (cached is not null && !ct.IsCancellationRequested) { return cached.Value; }
    }

    private async Task<Document> GetAsync(string path, CancellationToken ct, bool fresh = false)
    {
        cache.TryGetValue("public:" + path, out Document? cached);
        if (!fresh && cached is not null && DateTimeOffset.UtcNow - cached.LoadedAt < TimeSpan.FromMinutes(5)) return cached;
        try
        {
            using var response = await http.GetAsync(path, ct);
            response.EnsureSuccessStatusCode();
            using var json = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
            int Header(string name) => response.Headers.TryGetValues(name, out var values) && int.TryParse(values.FirstOrDefault(), out var number) ? number : 0;
            var document = new Document(json.RootElement.Clone(), Header("X-WP-Total"), Header("X-WP-TotalPages"), DateTimeOffset.UtcNow);
            cache.Set("public:" + path, document, new MemoryCacheEntryOptions { Size = 1, AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(24) });
            return document;
        }
        catch (Exception error) when (!ct.IsCancellationRequested && !fresh && cached is not null && error is HttpRequestException or TaskCanceledException)
        {
            return cached;
        }
    }

    public async Task<HomeContentResponse> HomeAsync(CancellationToken ct)
    {
        var markupTask = MarkupAsync("/", ct);
        var categoriesTask = CategoriesAsync(ct);
        var productsTask = ProductsAsync(new QueryCollection(new Dictionary<string, Microsoft.Extensions.Primitives.StringValues>
        {
            ["pageSize"] = "8", ["sort"] = "popularity",
        }), ct);
        await Task.WhenAll(markupTask, categoriesTask, productsTask);
        var root = PageRoot(await markupTask);
        var result = new HomeContentResponse { SourceUrl = "https://technocare.az/", UpdatedAt = DateTimeOffset.UtcNow };
        var hero = root.ChildNodes.FirstOrDefault(node => node.NodeType == HtmlNodeType.Element);
        if (hero is not null) result.Sections.Add(Section(hero, "hero", 0));
        foreach (var heading in root.Descendants("h2"))
        {
            var text = Clean(heading.InnerText).ToLowerInvariant();
            var type = text.Contains("partnyor") ? "partners"
                : text.Contains("standartlara") ? "quality"
                : text.Contains("hər növ sənaye") ? "projects"
                : text.Contains("peşəkar həllər") ? "services"
                : text.Contains("sənayenizi gücləndiririk") ? "about" : null;
            if (type is null || result.Sections.Any(section => section.Type == type)) continue;
            var container = heading.Ancestors().FirstOrDefault(node => HasClass(node, "e-con")) ?? heading.ParentNode ?? root;
            var section = Section(container, type, result.Sections.Count);
            section.Title = Clean(heading.InnerText);
            result.Sections.Add(section);
        }
        var categories = await categoriesTask;
        result.Sections.Insert(Math.Min(2, result.Sections.Count), new HomeSectionDto
        {
            Id = "categories", Type = "categories", Title = "Məhsullar üzrə kateqoriyalar",
            Items = categories.Items.Where(category => category.ParentId == 0).Take(12).Select(Item).ToList(),
        });
        var products = await productsTask;
        result.Sections.Insert(Math.Min(3, result.Sections.Count), new HomeSectionDto
        {
            Id = "best_sellers", Type = "best_sellers", Title = "Ən çox satılan məhsullar", Items = products.Items.Select(Item).ToList(),
        });
        // WhatsApp contact comes from the published website, not a private API.
        result.Sections.Add(new HomeSectionDto { Id = "contact", Type = "contact", Links = Links(root) });
        for (var i = 0; i < result.Sections.Count; i++) result.Sections[i].Order = i;
        return result;
    }

    public async Task<PagedShopProductsResponse> ProductsAsync(IQueryCollection query, CancellationToken ct)
    {
        var args = ProductQuery(query);
        var response = await GetAsync(QueryHelpers.AddQueryString("wp-json/wc/store/v1/products", args), ct);
        return new PagedShopProductsResponse
        {
            Items = response.Data.EnumerateArray().Select(MapProduct).ToList(),
            Page = int.Parse(args["page"]!), PageSize = int.Parse(args["per_page"]!),
            Total = response.Total, TotalPages = response.TotalPages,
        };
    }

    public static Dictionary<string, string?> ProductQuery(IQueryCollection query)
    {
        var args = new Dictionary<string, string?>
        {
            ["page"] = Integer(query["page"], 1, 1, 10000).ToString(),
            ["per_page"] = Integer(query["pageSize"], 20, 1, 100).ToString(),
        };
        var search = query["q"].ToString().Trim();
        if (search.Length > 100) search = search[..100];
        if (search.Length > 0) args["search"] = search;
        if (long.TryParse(query["category"], out var category) && category > 0) args["category"] = category.ToString();
        var brand = query["brand"].ToString();
        if (brand.Length is > 0 and <= 100)
        {
            args["attributes[0][attribute]"] = "pa_brand";
            args[long.TryParse(brand, out _) ? "attributes[0][term_id]" : "attributes[0][slug]"] = brand;
        }
        if (query["inStock"] == "true") args["stock_status[0]"] = "instock";
        foreach (var (input, output) in new[] { ("minPrice", "min_price"), ("maxPrice", "max_price") })
            if (decimal.TryParse(query[input], NumberStyles.Number, CultureInfo.InvariantCulture, out var price) && price >= 0)
                args[output] = decimal.Round(price * 100).ToString("0", CultureInfo.InvariantCulture);
        var sort = query["sort"].ToString();
        (args["orderby"], args["order"]) = sort switch
        {
            "price_asc" => ("price", "asc"), "price_desc" => ("price", "desc"),
            "name_asc" => ("title", "asc"), "name_desc" => ("title", "desc"),
            "popularity" => ("popularity", "desc"), _ => ("date", "desc"),
        };
        return args;
    }

    public async Task<ShopProductDto> ProductAsync(long id, bool fresh, CancellationToken ct) =>
        MapProduct((await GetAsync($"wp-json/wc/store/v1/products/{id}", ct, fresh)).Data);

    public async Task<ShopTaxonomyResponse> CategoriesAsync(CancellationToken ct) =>
        new() { Items = await TaxonomiesAsync("wp-json/wc/store/v1/products/categories", ct) };

    public async Task<ShopTaxonomyResponse> BrandsAsync(CancellationToken ct) =>
        new() { Items = await TaxonomiesAsync("wp-json/wc/store/v1/products/attributes/2/terms", ct) };

    private async Task<List<ShopTaxonomyDto>> TaxonomiesAsync(string path, CancellationToken ct)
    {
        var items = new List<ShopTaxonomyDto>();
        for (var page = 1; page <= 20; page++)
        {
            var response = await GetAsync($"{path}?per_page=100&page={page}", ct);
            items.AddRange(response.Data.EnumerateArray().Select(MapTaxonomy));
            if (page >= response.TotalPages) break;
        }
        return items;
    }

    public async Task<ShopSuggestionsResponse> SuggestionsAsync(IQueryCollection query, CancellationToken ct)
    {
        if (query["q"].ToString().Trim().Length < 2) return new();
        var products = await ProductsAsync(new QueryCollection(new Dictionary<string, Microsoft.Extensions.Primitives.StringValues>
        {
            ["q"] = query["q"], ["pageSize"] = Integer(query["limit"], 5, 1, 10).ToString(),
        }), ct);
        return new ShopSuggestionsResponse { Items = products.Items.Select(product => new ShopSuggestionDto
        {
            Id = product.Id, Name = product.Name, Sku = product.Sku, Brand = product.Brand,
            ImageUrl = product.Images.FirstOrDefault() ?? "", Price = product.Price, InStock = product.InStock, OnSale = product.OnSale,
        }).ToList() };
    }

    public async Task<PagedSiteProjectsResponse> ProjectsAsync(IQueryCollection query, CancellationToken ct)
    {
        var items = ParseProjects(await MarkupAsync("/layiheler", ct));
        var search = query["q"].ToString().Trim();
        if (search.Length > 0) items = items.Where(item => (item.Name + " " + item.Description).Contains(search, StringComparison.OrdinalIgnoreCase)).ToList();
        var number = Integer(query["page"], 1, 1, 10000);
        var size = Integer(query["pageSize"], 12, 1, 100);
        return new PagedSiteProjectsResponse { Items = items.Skip((number - 1) * size).Take(size).ToList(), Page = number, PageSize = size, Total = items.Count, TotalPages = (int)Math.Ceiling(items.Count / (double)size) };
    }

    public static List<SiteProjectDto> ParseProjects(string html)
    {
        var root = PageRoot(html);
        var items = new List<SiteProjectDto>();
        var seen = new HashSet<string>();
        foreach (var heading in root.Descendants().Where(node => node.Name is "h1" or "h2" or "h3" or "h4"))
        {
            var anchor = heading.Descendants("a").FirstOrDefault();
            var url = PublicUrl(anchor?.GetAttributeValue("href", ""));
            var title = Clean(heading.InnerText);
            if (title.Length == 0 || url.Length == 0 || !seen.Add(url)) continue;
            var path = new Uri(url).AbsolutePath.Trim('/');
            if (path is "layiheler" or "xidmetler" or "tedris" || path.StartsWith("mehsullar/")) continue;
            var container = heading;
            foreach (var parent in heading.Ancestors().Take(7))
            {
                container = parent;
                if (Images(parent).Count > 0) break;
            }
            var images = Images(container);
            // A URL-derived stable identifier preserves client deduplication.
            var id = BitConverter.ToUInt32(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(url)), 0);
            items.Add(new SiteProjectDto
            {
                Id = id, Name = title, Url = url, Description = string.Join("\n", container.Descendants("p").Select(node => Clean(node.InnerText))),
                Content = string.Join("\n", container.Descendants("p").Select(node => Clean(node.InnerText))),
                ImageUrl = images.FirstOrDefault() ?? "", Images = images,
            });
        }
        return items;
    }

    public async Task<SiteContentCollectionResponse> ContentAsync(string slug, CancellationToken ct)
    {
        var root = PageRoot(await MarkupAsync("/" + slug, ct));
        var items = new List<SiteContentItemDto>();
        foreach (var heading in root.Descendants().Where(node => node.Name is "h2" or "h3"))
        {
            var title = Clean(heading.InnerText);
            if (title.Length < 5) continue;
            var container = heading.Ancestors().FirstOrDefault(node => HasClass(node, "e-con")) ?? heading.ParentNode ?? root;
            var images = Images(container);
            var body = string.Join("\n\n", container.Descendants("p").Select(node => Clean(node.InnerText)).Where(text => text.Length > 0));
            items.Add(new SiteContentItemDto { Id = items.Count + 1, Title = title, Summary = body, Body = body, Images = images, ImageUrl = images.FirstOrDefault() ?? "", Url = Links(container).FirstOrDefault()?.Url ?? "https://technocare.az/" + slug, UpdatedAt = DateTimeOffset.UtcNow });
        }
        return new SiteContentCollectionResponse { SourceUrl = "https://technocare.az/" + slug, UpdatedAt = DateTimeOffset.UtcNow, Items = items };
    }

    public async Task<object[]> NotificationsAsync(CancellationToken ct)
    {
        // Public, in-app updates from published pages. Push/webhooks need website admin access.
        var pages = (await GetAsync("wp-json/wp/v2/pages?per_page=20&orderby=modified&order=desc&_fields=id,title,excerpt,link,modified_gmt", ct)).Data;
        return pages.EnumerateArray().Select(page => (object)new
        {
            id = $"page-{page.GetProperty("id").GetInt64()}-{Text(page, "modified_gmt")}",
            title = Clean(Text(page.GetProperty("title"), "rendered")),
            message = "Saytda yenilənmiş məlumatı nəzərdən keçirin.", timestamp = Modified(page),
            url = Text(page, "link"), category = "website", isBroadcast = true, read = false,
        }).ToArray();
    }

    public static ShopProductDto MapProduct(JsonElement value)
    {
        var prices = value.GetProperty("prices");
        var minor = prices.TryGetProperty("currency_minor_unit", out var unit) ? unit.GetInt32() : 2;
        decimal? Money(string key) => decimal.TryParse(Text(prices, key), NumberStyles.Number, CultureInfo.InvariantCulture, out var amount) ? amount / (decimal)Math.Pow(10, minor) : null;
        var brand = "";
        if (value.TryGetProperty("attributes", out var attributes))
            foreach (var attribute in attributes.EnumerateArray())
                if (Text(attribute, "taxonomy") == "pa_brand" && attribute.TryGetProperty("terms", out var terms) && terms.GetArrayLength() > 0)
                    brand = Clean(Text(terms[0], "name"));
        return new ShopProductDto
        {
            Id = value.GetProperty("id").GetInt64(), Name = Clean(Text(value, "name")), Slug = Text(value, "slug"), Sku = Text(value, "sku"), Brand = brand,
            Description = PlainHtml(Text(value, "description")), ShortDescription = PlainHtml(Text(value, "short_description")),
            Price = Money("price"), RegularPrice = Money("regular_price"), SalePrice = Money("sale_price"),
            CurrencyCode = Text(prices, "currency_code"), CurrencySymbol = WebUtility.HtmlDecode(Text(prices, "currency_symbol")),
            OnSale = Flag(value, "on_sale"), InStock = Flag(value, "is_in_stock"), Purchasable = Flag(value, "is_purchasable"),
            StockStatus = Flag(value, "is_in_stock") ? "instock" : "outofstock", Permalink = Text(value, "permalink"),
            Categories = value.TryGetProperty("categories", out var categories) ? categories.EnumerateArray().Select(MapTaxonomy).ToList() : [],
            Images = value.TryGetProperty("images", out var images) ? images.EnumerateArray().Select(image => Text(image, "src")).Where(url => url.StartsWith("https://technocare.az/", StringComparison.OrdinalIgnoreCase)).ToList() : [],
        };
    }

    private static ShopTaxonomyDto MapTaxonomy(JsonElement value) => new()
    {
        Id = value.GetProperty("id").GetInt64(), Name = Clean(Text(value, "name")), Slug = Text(value, "slug"),
        ParentId = value.TryGetProperty("parent", out var parent) ? parent.GetInt64() : 0,
        Count = value.TryGetProperty("count", out var count) ? count.GetInt32() : 0,
        ImageUrl = value.TryGetProperty("image", out var image) && image.ValueKind == JsonValueKind.Object ? Text(image, "src") : "",
    };
    private static HomeSectionDto Section(HtmlNode node, string type, int order) => new()
    {
        Id = type, Type = type, Order = order,
        Title = Clean(node.Descendants().FirstOrDefault(child => child.Name is "h1" or "h2" or "h3")?.InnerText ?? ""),
        Body = string.Join("\n\n", node.Descendants("p").Select(child => Clean(child.InnerText)).Where(text => text.Length > 20).Distinct().Take(4)),
        Images = Images(node).Take(16).ToList(), Links = Links(node),
    };
    private static List<string> Images(HtmlNode node)
    {
        var images = node.Descendants("img")
            .Select(image => PublicUrl(image.GetAttributeValue("data-lazy-src", image.GetAttributeValue("src", ""))))
            .Where(url => url.Contains("/wp-content/uploads/", StringComparison.Ordinal)).ToList();
        // The live Woodmart hero uses CSS backgrounds rather than img elements.
        images.AddRange(Regex.Matches(node.InnerHtml, "url\\(\\s*['\"]?(https://technocare\\.az/wp-content/uploads/[^)'\"\\s]+)", RegexOptions.IgnoreCase, TimeSpan.FromSeconds(1))
            .Select(match => PublicUrl(match.Groups[1].Value)).Where(url => url.Length > 0));
        return images.Distinct().ToList();
    }
    private static List<HomeLinkDto> Links(HtmlNode node) => node.Descendants("a").Select(anchor => new HomeLinkDto
    {
        Label = Clean(anchor.InnerText), Url = ContactUrl(anchor.GetAttributeValue("href", "")),
    }).Where(link => link.Url.Length > 0 && (link.Label.Length > 0 || link.Url.StartsWith("https://wa.me/", StringComparison.Ordinal)))
        .DistinctBy(link => link.Url).Take(40).ToList();
    private static string ContactUrl(string value)
    {
        if (Uri.TryCreate(WebUtility.HtmlDecode(value), UriKind.Absolute, out var uri) && uri.Scheme == "https" && uri.Host is "wa.me" or "api.whatsapp.com") return uri.AbsoluteUri;
        return PublicUrl(value);
    }
    private static string PublicUrl(string? value) => !string.IsNullOrWhiteSpace(value) && Uri.TryCreate(new Uri("https://technocare.az/"), WebUtility.HtmlDecode(value), out var uri) && uri.Scheme == "https" && uri.Host == "technocare.az" && string.IsNullOrEmpty(uri.UserInfo) && uri.IsDefaultPort ? uri.AbsoluteUri : "";
    private static HtmlDocument Html(string value) { var document = new HtmlDocument(); document.LoadHtml(value); return document; }
    private static HtmlNode PageRoot(string html)
    {
        var document = Html(html);
        return document.DocumentNode.Descendants().FirstOrDefault(node => node.GetAttributeValue("data-elementor-type", "") == "wp-page")
            ?? document.DocumentNode.SelectSingleNode("//main") ?? document.DocumentNode;
    }
    private static bool HasClass(HtmlNode node, string value) => node.GetAttributeValue("class", "").Split(' ').Contains(value);
    private static string PlainHtml(string html) => Clean(Html(html).DocumentNode.InnerText);
    private static string Clean(string value) => Regex.Replace(WebUtility.HtmlDecode(value), @"\s+", " ").Trim();
    private static string Text(JsonElement value, string key) => value.TryGetProperty(key, out var property) && property.ValueKind == JsonValueKind.String ? property.GetString() ?? "" : "";
    private static bool Flag(JsonElement value, string key) => value.TryGetProperty(key, out var property) && property.ValueKind == JsonValueKind.True;
    private static DateTimeOffset Modified(JsonElement value) => DateTimeOffset.TryParse(Text(value, "modified_gmt") + "Z", out var date) ? date : DateTimeOffset.UtcNow;
    private static int Integer(string? value, int fallback, int min, int max) => int.TryParse(value, out var number) ? Math.Clamp(number, min, max) : fallback;
    private static JsonElement Item<T>(T value) => JsonSerializer.SerializeToElement(value, JsonOptions);
}
