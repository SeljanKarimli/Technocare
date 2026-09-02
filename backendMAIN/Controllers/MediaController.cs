using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers;

[ApiController]
[Route("api/v1/media")]
public sealed class MediaController : ControllerBase
{
    private const long MaxImageBytes = 15 * 1024 * 1024;
    private static readonly HashSet<string> AllowedMediaTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/avif",
        "image/gif",
        "image/jpeg",
        "image/png",
        "image/webp",
    };

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<MediaController> _logger;

    public MediaController(
        IHttpClientFactory httpClientFactory,
        ILogger<MediaController> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    [HttpGet]
    [AllowAnonymous]
    [ResponseCache(
        Duration = 604800,
        Location = ResponseCacheLocation.Any,
        VaryByQueryKeys = ["url"])]
    public async Task<IActionResult> Get(
        [FromQuery] string? url,
        CancellationToken cancellationToken)
    {
        if (!MediaProxySource.TryNormalize(url, out var source))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Şəkil ünvanı düzgün deyil.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, source);
            using var response = await _httpClientFactory
                .CreateClient("TechnocareMedia")
                .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return StatusCode(StatusCodes.Status502BadGateway, new ProblemDetails
                {
                    Title = "Şəkli yükləmək mümkün olmadı.",
                    Status = StatusCodes.Status502BadGateway,
                });
            }

            var mediaType = response.Content.Headers.ContentType?.MediaType;
            if (mediaType is null || !AllowedMediaTypes.Contains(mediaType))
            {
                return StatusCode(StatusCodes.Status502BadGateway, new ProblemDetails
                {
                    Title = "Dəstəklənməyən şəkil formatı.",
                    Status = StatusCodes.Status502BadGateway,
                });
            }
            if (response.Content.Headers.ContentLength > MaxImageBytes)
            {
                return StatusCode(StatusCodes.Status502BadGateway, new ProblemDetails
                {
                    Title = "Şəkil faylı icazə verilən ölçüdən böyükdür.",
                    Status = StatusCodes.Status502BadGateway,
                });
            }

            await response.Content.LoadIntoBufferAsync(MaxImageBytes);
            var image = await response.Content.ReadAsByteArrayAsync(cancellationToken);
            Response.Headers.CacheControl = "public,max-age=604800";
            Response.Headers.Append("X-Content-Type-Options", "nosniff");
            return File(image, mediaType);
        }
        catch (Exception exception) when (
            exception is HttpRequestException ||
            exception is TaskCanceledException && !cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning(
                "Technocare media request failed for {Path}: {ExceptionType}",
                source.AbsolutePath,
                exception.GetType().Name);
            return StatusCode(StatusCodes.Status502BadGateway, new ProblemDetails
            {
                Title = "Şəkil xidməti müvəqqəti əlçatan deyil.",
                Status = StatusCodes.Status502BadGateway,
            });
        }
    }
}
