using System.Reflection;
using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Security.Cryptography;
using backend.Controllers;
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace backendMAIN.Tests;

public sealed class ApiContractTests
{
    [Fact]
    public void ProductEnvelope_UsesStableCamelCaseContract()
    {
        var payload = new PagedShopProductsResponse
        {
            Page = 1,
            PageSize = 20,
            Total = 1,
            TotalPages = 1,
            Items = [new ShopProductDto { Id = 42, Name = "Siemens S7", Sku = "6ES7" }],
        };

        var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions(JsonSerializerDefaults.Web));

        Assert.Contains("\"items\"", json);
        Assert.Contains("\"pageSize\":20", json);
        Assert.Contains("\"sku\":\"6ES7\"", json);
    }

    [Fact]
    public void SuggestionEnvelope_UsesExpectedPublicFields()
    {
        var payload = new ShopSuggestionsResponse
        {
            Items = [new ShopSuggestionDto
            {
                Id = 17,
                Name = "Sənaye sensoru",
                Sku = "SN-001",
                Brand = "Siemens",
                ImageUrl = "https://technocare.az/sensor.webp",
                Price = 12.5m,
                InStock = true,
            }],
        };

        var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions(JsonSerializerDefaults.Web));

        Assert.Contains("\"sku\":\"SN-001\"", json);
        Assert.Contains("\"imageUrl\"", json);
        Assert.Contains("\"inStock\":true", json);
    }

    [Theory]
    [InlineData("  USER@Example.COM ", "user@example.com")]
    [InlineData("ƏLI@TECHNOCARE.AZ", "əli@technocare.az")]
    public void EmailNormalization_IsCaseInsensitiveAndTrimmed(string input, string expected)
    {
        Assert.Equal(expected, UserService.NormalizeEmail(input));
    }

    [Fact]
    public void GuestApplicationValidation_RejectsInvalidPhoneAndOversizedMessage()
    {
        var request = new CreateServiceApplicationRequest
        {
            Name = "Test User",
            Email = "test@example.com",
            Phone = "123",
            AppliedFor = "Avtomatika Xidməti",
            Message = new string('x', 2001),
        };
        var results = new List<ValidationResult>();

        var valid = Validator.TryValidateObject(request, new ValidationContext(request), results, true);

        Assert.False(valid);
        Assert.Contains(results, result => result.MemberNames.Contains(nameof(request.Phone)));
        Assert.Contains(results, result => result.MemberNames.Contains(nameof(request.Message)));
    }

    [Theory]
    [InlineData("123456", true)]
    [InlineData("12345", false)]
    [InlineData("ABC123", false)]
    public void EmailVerification_RequiresSixDigits(string code, bool expected)
    {
        var request = new VerifyEmailRequest { Email = "user@example.com", Code = code };
        var results = new List<ValidationResult>();

        var valid = Validator.TryValidateObject(request, new ValidationContext(request), results, true);

        Assert.Equal(expected, valid);
    }

    [Fact]
    public void ApplicationEmail_IsAddressedByConfigAndEscapesSubmittedHtml()
    {
        var application = new ServiceApplication
        {
            ApplicantName = "<script>alert(1)</script>",
            ApplicantEmail = "USER@EXAMPLE.COM",
            ApplicantPhone = "+994 50 000 00 00",
            AppliedFor = "Avtomatika",
            AppliedSubService = "PLC <b>servis</b>",
            Message = "Salam & təşəkkür",
            ApplicationDate = new DateTime(2026, 9, 2, 10, 0, 0, DateTimeKind.Utc),
        };

        var email = ApplicationEmailComposer.Service(application);

        Assert.Equal("Yeni xidmət müraciəti — Avtomatika", email.Subject);
        Assert.DoesNotContain("<script>", email.HtmlBody);
        Assert.Contains("&lt;script&gt;", email.HtmlBody);
        Assert.Contains("Salam &amp;", email.HtmlBody);
    }

    [Fact]
    public void WebsiteEventSignature_RejectsReplayAndTampering()
    {
        const string secret = "test-shared-secret-at-least-32-chars";
        const string body = "{\"eventId\":\"event-123456\"}";
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
        const string nonce = "unique-nonce-123456789";
        var payload = $"{timestamp}.{nonce}.{body}";
        var signature = Convert.ToHexString(
            HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes(payload)))
            .ToLowerInvariant();
        var verifier = new SiteEventSignatureVerifier(
            Options.Create(new TechnocareSiteOptions { SharedSecret = secret }),
            new MemoryCache(new MemoryCacheOptions()));

        Assert.True(verifier.Verify(body, timestamp, nonce, signature));
        Assert.False(verifier.Verify(body, timestamp, nonce, signature));
        Assert.False(new SiteEventSignatureVerifier(
            Options.Create(new TechnocareSiteOptions { SharedSecret = secret }),
            new MemoryCache(new MemoryCacheOptions()))
            .Verify(body + " ", timestamp, nonce, signature));
    }

    [Theory]
    [InlineData("https://technocare.az/wp-content/uploads/2024/04/Azərbaycan.png", true)]
    [InlineData("https://technocare.az/wp-content/uploads/manual.pdf", false)]
    [InlineData("https://technocare.az/layiheler/project.webp", false)]
    [InlineData("https://technocare.az.evil.example/wp-content/uploads/image.png", false)]
    [InlineData("http://technocare.az/wp-content/uploads/image.png", false)]
    public void MediaProxy_OnlyAllowsTechnocareUploadImages(string value, bool expected)
    {
        Assert.Equal(expected, MediaProxySource.TryNormalize(value, out _));
    }

    [Theory]
    [InlineData(nameof(ShopController.Cart))]
    [InlineData(nameof(ShopController.AddCartItem))]
    [InlineData(nameof(ShopController.CheckoutSession))]
    [InlineData(nameof(ShopController.Orders))]
    public void ProtectedShopActions_RequireAuthorization(string methodName)
    {
        var method = typeof(ShopController).GetMethod(methodName)
            ?? throw new InvalidOperationException($"Missing action {methodName}.");

        Assert.NotNull(method.GetCustomAttribute<AuthorizeAttribute>());
        Assert.Null(method.GetCustomAttribute<AllowAnonymousAttribute>());
    }

    [Fact]
    public async Task UnexpectedErrors_ReturnSanitizedProblemDetails()
    {
        var handler = new ApiExceptionHandler(NullLogger<ApiExceptionHandler>.Instance);
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();

        await handler.TryHandleAsync(context, new InvalidOperationException("secret database detail"), default);
        context.Response.Body.Position = 0;
        var body = await new StreamReader(context.Response.Body).ReadToEndAsync();

        Assert.Equal(StatusCodes.Status500InternalServerError, context.Response.StatusCode);
        Assert.DoesNotContain("secret database detail", body);
        Assert.Contains("Please try again later", body);
    }

    [Fact]
    public async Task WebsiteContent_UsesFreshFiveMinuteCache()
    {
        var handler = new SequenceHandler(
            Json(HttpStatusCode.OK, "{\"schemaVersion\":1,\"updatedAt\":\"2026-08-31T00:00:00Z\",\"sourceUrl\":\"https://technocare.az\",\"sections\":[]}"));
        var client = CreateSiteClient(handler, cacheMinutes: 5);

        var first = await client.GetHomeAsync(default);
        var second = await client.GetHomeAsync(default);

        Assert.Equal(1, handler.CallCount);
        Assert.Same(first, second);
    }

    [Fact]
    public async Task WebsiteContent_ReturnsStaleValueWhenDependencyFails()
    {
        var handler = new SequenceHandler(
            Json(HttpStatusCode.OK, "{\"schemaVersion\":1,\"updatedAt\":\"2026-08-31T00:00:00Z\",\"sourceUrl\":\"https://technocare.az\",\"sections\":[]}"),
            _ => throw new HttpRequestException("dependency offline"));
        var client = CreateSiteClient(handler, cacheMinutes: 0);

        var first = await client.GetHomeAsync(default);
        var stale = await client.GetHomeAsync(default);

        Assert.Equal(2, handler.CallCount);
        Assert.Equal(first.UpdatedAt, stale.UpdatedAt);
    }

    private static TechnocareSiteClient CreateSiteClient(HttpMessageHandler handler, int cacheMinutes)
    {
        var http = new HttpClient(handler) { BaseAddress = new Uri("https://technocare.az/") };
        var cache = new MemoryCache(new MemoryCacheOptions());
        var options = Options.Create(new TechnocareSiteOptions
        {
            BaseUrl = "https://technocare.az",
            CacheMinutes = cacheMinutes,
            TimeoutSeconds = 15,
            SharedSecret = "test-shared-secret",
        });
        return new TechnocareSiteClient(http, cache, options, NullLogger<TechnocareSiteClient>.Instance);
    }

    private static Func<HttpRequestMessage, HttpResponseMessage> Json(HttpStatusCode statusCode, string body) => _ =>
    {
        var response = new HttpResponseMessage(statusCode)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json"),
        };
        response.Headers.ETag = new EntityTagHeaderValue("\"home-v1\"");
        return response;
    };

    private sealed class SequenceHandler(params Func<HttpRequestMessage, HttpResponseMessage>[] responses) : HttpMessageHandler
    {
        private int _index;
        public int CallCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            CallCount++;
            var response = responses[Math.Min(_index, responses.Length - 1)](request);
            _index++;
            return Task.FromResult(response);
        }
    }
}
