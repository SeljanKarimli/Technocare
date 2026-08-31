using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using backend.Models;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace backend.Services;

public interface ITechnocareSiteClient
{
    Task<HomeContentResponse> GetHomeAsync(CancellationToken cancellationToken);
    Task<PagedSiteProjectsResponse> GetProjectsAsync(int page, int pageSize, CancellationToken cancellationToken);
    Task<SiteContentCollectionResponse> GetServicesAsync(CancellationToken cancellationToken);
    Task<SiteContentCollectionResponse> GetEducationAsync(CancellationToken cancellationToken);
    Task<PagedShopProductsResponse> GetProductsAsync(string queryString, CancellationToken cancellationToken);
    Task<ShopProductDto> GetProductAsync(long productId, CancellationToken cancellationToken);
    Task<ShopTaxonomyResponse> GetCategoriesAsync(CancellationToken cancellationToken);
    Task<ShopTaxonomyResponse> GetBrandsAsync(CancellationToken cancellationToken);
    Task<CheckoutSessionResponse> CreateCheckoutSessionAsync(string userId, string email, IEnumerable<ShopCartItem> items, CancellationToken cancellationToken);
    Task<PagedShopOrdersResponse> GetOrdersAsync(string userId, int page, CancellationToken cancellationToken);
}

public sealed class TechnocareSiteClient : ITechnocareSiteClient
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = true,
    };

    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;
    private readonly TechnocareSiteOptions _options;
    private readonly ILogger<TechnocareSiteClient> _logger;

    public TechnocareSiteClient(
        HttpClient httpClient,
        IMemoryCache cache,
        IOptions<TechnocareSiteOptions> options,
        ILogger<TechnocareSiteClient> logger)
    {
        _httpClient = httpClient;
        _cache = cache;
        _options = options.Value;
        _logger = logger;
    }

    public Task<HomeContentResponse> GetHomeAsync(CancellationToken cancellationToken) =>
        GetCachedAsync<HomeContentResponse>("home", "wp-json/technocare-app/v1/home", cancellationToken);

    public Task<PagedSiteProjectsResponse> GetProjectsAsync(int page, int pageSize, CancellationToken cancellationToken)
    {
        var safePage = Math.Max(1, page);
        var safePageSize = Math.Clamp(pageSize, 1, 30);
        var query = $"?page={safePage}&pageSize={safePageSize}";
        return GetCachedAsync<PagedSiteProjectsResponse>("projects:" + query, "wp-json/technocare-app/v1/projects" + query, cancellationToken);
    }

    public Task<SiteContentCollectionResponse> GetServicesAsync(CancellationToken cancellationToken) =>
        GetCachedAsync<SiteContentCollectionResponse>("services", "wp-json/technocare-app/v1/services", cancellationToken);

    public Task<SiteContentCollectionResponse> GetEducationAsync(CancellationToken cancellationToken) =>
        GetCachedAsync<SiteContentCollectionResponse>("education", "wp-json/technocare-app/v1/education", cancellationToken);

    public Task<PagedShopProductsResponse> GetProductsAsync(string queryString, CancellationToken cancellationToken) =>
        GetCachedAsync<PagedShopProductsResponse>("products:" + queryString, "wp-json/technocare-app/v1/products" + queryString, cancellationToken);

    public Task<ShopProductDto> GetProductAsync(long productId, CancellationToken cancellationToken) =>
        GetCachedAsync<ShopProductDto>($"product:{productId}", $"wp-json/technocare-app/v1/products/{productId}", cancellationToken);

    public Task<ShopTaxonomyResponse> GetCategoriesAsync(CancellationToken cancellationToken) =>
        GetCachedAsync<ShopTaxonomyResponse>("categories", "wp-json/technocare-app/v1/categories", cancellationToken);

    public Task<ShopTaxonomyResponse> GetBrandsAsync(CancellationToken cancellationToken) =>
        GetCachedAsync<ShopTaxonomyResponse>("brands", "wp-json/technocare-app/v1/brands", cancellationToken);

    public Task<CheckoutSessionResponse> CreateCheckoutSessionAsync(
        string userId,
        string email,
        IEnumerable<ShopCartItem> items,
        CancellationToken cancellationToken) =>
        PostSignedAsync<CheckoutSessionResponse>("wp-json/technocare-app/v1/checkout-session", new WordPressCheckoutRequest
        {
            AppUserId = userId,
            Email = email,
            Items = items.Select(item => new WordPressCheckoutItem
            {
                ProductId = item.WooProductId,
                Quantity = item.Quantity,
            }).ToList(),
        }, cancellationToken);

    public Task<PagedShopOrdersResponse> GetOrdersAsync(string userId, int page, CancellationToken cancellationToken) =>
        PostSignedAsync<PagedShopOrdersResponse>("wp-json/technocare-app/v1/orders", new WordPressOrderRequest
        {
            AppUserId = userId,
            Page = Math.Max(1, page),
        }, cancellationToken);

    private async Task<T> GetCachedAsync<T>(string key, string relativeUrl, CancellationToken cancellationToken)
    {
        var cacheKey = "technocare-site:" + key;
        _cache.TryGetValue(cacheKey, out CachedSiteResponse<T>? cached);
        if (cached is not null && cached.FreshUntil > DateTimeOffset.UtcNow)
        {
            return cached.Value;
        }

        try
        {
            using var response = await SendGetWithRetryAsync(relativeUrl, cached, cancellationToken);
            if (response.StatusCode == HttpStatusCode.NotModified && cached is not null)
            {
                var refreshed = cached with { FreshUntil = DateTimeOffset.UtcNow.AddMinutes(_options.CacheMinutes) };
                Store(cacheKey, refreshed);
                return refreshed.Value;
            }

            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                throw new TechnocareSiteException((int) response.StatusCode, SafeMessage(response.StatusCode));
            }

            var value = JsonSerializer.Deserialize<T>(body, JsonOptions)
                ?? throw new TechnocareSiteException(502, "The website returned an empty response.");
            var entry = new CachedSiteResponse<T>(
                value,
                DateTimeOffset.UtcNow.AddMinutes(_options.CacheMinutes),
                response.Headers.ETag?.ToString(),
                response.Content.Headers.LastModified);
            Store(cacheKey, entry);
            return value;
        }
        catch (Exception exception) when (cached is not null && exception is not OperationCanceledException)
        {
            _logger.LogWarning(exception, "Technocare website request failed for {RelativeUrl}; returning stale content.", relativeUrl);
            return cached.Value;
        }
        catch (Exception exception) when (
            exception is HttpRequestException ||
            exception is TimeoutException ||
            exception is TaskCanceledException && !cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning("Technocare website request failed for {RelativeUrl}: {ExceptionType}", relativeUrl, exception.GetType().Name);
            throw new TechnocareSiteException(502, "The Technocare website is temporarily unavailable.");
        }
    }

    private async Task<HttpResponseMessage> SendGetWithRetryAsync<T>(
        string relativeUrl,
        CachedSiteResponse<T>? cached,
        CancellationToken cancellationToken)
    {
        for (var attempt = 1; attempt <= 3; attempt++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, relativeUrl);
            if (!string.IsNullOrWhiteSpace(cached?.ETag))
            {
                request.Headers.TryAddWithoutValidation("If-None-Match", cached.ETag);
            }
            if (cached?.LastModified is not null)
            {
                request.Headers.IfModifiedSince = cached.LastModified;
            }

            var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            var transient = response.StatusCode is HttpStatusCode.RequestTimeout
                or HttpStatusCode.TooManyRequests
                or HttpStatusCode.InternalServerError
                or HttpStatusCode.BadGateway
                or HttpStatusCode.ServiceUnavailable
                or HttpStatusCode.GatewayTimeout;
            if (!transient || attempt == 3)
            {
                return response;
            }
            response.Dispose();
            await Task.Delay(TimeSpan.FromMilliseconds(200 * Math.Pow(2, attempt - 1)), cancellationToken);
        }
        throw new TechnocareSiteException(502, "The Technocare website is temporarily unavailable.");
    }

    private void Store<T>(string key, CachedSiteResponse<T> value)
    {
        _cache.Set(key, value, new MemoryCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(24),
            Size = 1,
        });
    }

    private async Task<T> PostSignedAsync<T>(string relativeUrl, object payload, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.SharedSecret))
        {
            throw new TechnocareSiteException(503, "Checkout integration is not configured.");
        }

        var body = JsonSerializer.Serialize(payload, JsonOptions);
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
        var nonce = Guid.NewGuid().ToString("N");
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(_options.SharedSecret));
        var signature = Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(timestamp + "." + nonce + "." + body))).ToLowerInvariant();
        using var request = new HttpRequestMessage(HttpMethod.Post, relativeUrl)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json"),
        };
        request.Headers.Add("X-Technocare-Timestamp", timestamp);
        request.Headers.Add("X-Technocare-Nonce", nonce);
        request.Headers.Add("X-Technocare-Signature", signature);

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new TechnocareSiteException((int) response.StatusCode, SafeMessage(response.StatusCode));
        }
        return JsonSerializer.Deserialize<T>(responseBody, JsonOptions)
            ?? throw new TechnocareSiteException(502, "The website returned an empty response.");
    }

    private static string SafeMessage(HttpStatusCode statusCode) => statusCode switch
    {
        HttpStatusCode.NotFound => "The requested website item was not found.",
        HttpStatusCode.Conflict => "A product changed or is no longer available.",
        HttpStatusCode.UnprocessableEntity => "The website rejected the request data.",
        _ => "The Technocare website is temporarily unavailable.",
    };

    private sealed record CachedSiteResponse<T>(
        T Value,
        DateTimeOffset FreshUntil,
        string? ETag,
        DateTimeOffset? LastModified);
}

public sealed class TechnocareSiteException : Exception
{
    public TechnocareSiteException(int statusCode, string message) : base(message)
    {
        StatusCode = statusCode;
    }

    public int StatusCode { get; }
}
