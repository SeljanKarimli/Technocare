using System.Net;
using System.Threading.RateLimiting;
using backend.Controllers;
using Microsoft.AspNetCore.Mvc.ApplicationParts;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.RateLimiting;

namespace backend.Services;

/// <summary>Public WordPress/WooCommerce reads for the guest-only mobile app.</summary>
public static class PublicWebsiteHost
{
    public static async Task RunAsync(WebApplicationBuilder builder)
    {
        builder.Services.AddMemoryCache(options => options.SizeLimit = 64);
        builder.Services.AddHttpClient<PublicWebsiteClient>(client =>
        {
            client.BaseAddress = new Uri("https://technocare.az/");
            client.Timeout = TimeSpan.FromSeconds(18);
            client.DefaultRequestHeaders.UserAgent.ParseAdd("TechnocareApp/2.1 (+https://technocare.az)");
            client.DefaultRequestHeaders.Accept.ParseAdd("application/json");
        }).ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
        {
            AllowAutoRedirect = false,
            AutomaticDecompression = DecompressionMethods.All,
        });
        builder.Services.AddHttpClient("TechnocareMedia", client =>
        {
            client.Timeout = TimeSpan.FromSeconds(25);
            client.DefaultRequestHeaders.UserAgent.ParseAdd("TechnocareApp/2.1 (+https://technocare.az)");
        }).ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
        {
            AllowAutoRedirect = false,
            AutomaticDecompression = DecompressionMethods.All,
        });
        // Reuse the existing, tested allowlisted image proxy, without exposing
        // controllers whose constructors or operations require MongoDB.
        builder.Services.AddControllers().ConfigureApplicationPartManager(manager =>
            manager.FeatureProviders.Add(new MediaOnlyControllers()));
        builder.Services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = 429;
            options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
                RateLimitPartition.GetFixedWindowLimiter(
                    context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 120, Window = TimeSpan.FromMinutes(1), QueueLimit = 0,
                    }));
        });
        var app = builder.Build();
        app.Use(async (context, next) =>
        {
            try { await next(); }
            catch (Exception error) when (error is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException or InvalidDataException)
            {
                if (context.RequestAborted.IsCancellationRequested) return;
                app.Logger.LogWarning("Public website request failed: {ErrorType}", error.GetType().Name);
                context.Response.StatusCode = error is HttpRequestException { StatusCode: HttpStatusCode.NotFound } ? 404 : 502;
                await context.Response.WriteAsJsonAsync(new { message = "Technocare saytı hazırda əlçatan deyil. Yenidən cəhd edin." });
            }
        });
        app.UseRateLimiter();
        app.MapControllers();
        app.MapGet("/health/live", () => Results.Ok(new { status = "healthy", mode = "public-website" }));
        app.MapGet("/health/ready", async (PublicWebsiteClient site, CancellationToken ct) =>
        {
            await site.HomeAsync(ct);
            await site.ProductsAsync(new QueryCollection(), ct);
            return Results.Ok(new { status = "healthy", mode = "public-website" });
        });
        app.MapGet("/api/v1/content/home", (PublicWebsiteClient site, CancellationToken ct) => site.HomeAsync(ct));
        app.MapGet("/api/v1/content/projects", (HttpRequest request, PublicWebsiteClient site, CancellationToken ct) => site.ProjectsAsync(request.Query, ct));
        app.MapGet("/api/v1/content/services", (PublicWebsiteClient site, CancellationToken ct) => site.ContentAsync("xidmetler", ct));
        app.MapGet("/api/v1/content/education", (PublicWebsiteClient site, CancellationToken ct) => site.ContentAsync("tedris", ct));
        app.MapGet("/api/v1/shop/products", (HttpRequest request, PublicWebsiteClient site, CancellationToken ct) => site.ProductsAsync(request.Query, ct));
        app.MapGet("/api/v1/shop/products/{id:long}", (long id, HttpRequest request, PublicWebsiteClient site, CancellationToken ct) => site.ProductAsync(id, request.Query["fresh"] == "true", ct));
        app.MapGet("/api/v1/shop/categories", (PublicWebsiteClient site, CancellationToken ct) => site.CategoriesAsync(ct));
        app.MapGet("/api/v1/shop/brands", (PublicWebsiteClient site, CancellationToken ct) => site.BrandsAsync(ct));
        app.MapGet("/api/v1/shop/suggestions", (HttpRequest request, PublicWebsiteClient site, CancellationToken ct) => site.SuggestionsAsync(request.Query, ct));
        app.MapGet("/api/notifications/public", (PublicWebsiteClient site, CancellationToken ct) => site.NotificationsAsync(ct));
        // No static admin files, auth, database writes or fake submission success.
        await app.RunAsync();
    }

    private sealed class MediaOnlyControllers : IApplicationFeatureProvider<ControllerFeature>
    {
        public void PopulateFeature(IEnumerable<ApplicationPart> parts, ControllerFeature feature)
        {
            foreach (var controller in feature.Controllers.Where(type => type.AsType() != typeof(MediaController)).ToList())
                feature.Controllers.Remove(controller);
        }
    }
}
