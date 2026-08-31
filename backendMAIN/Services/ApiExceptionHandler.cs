using System.Net;
using backend.Models;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace backend.Services;

public sealed class ApiExceptionHandler : IExceptionHandler
{
    private readonly ILogger<ApiExceptionHandler> _logger;

    public ApiExceptionHandler(ILogger<ApiExceptionHandler> logger)
    {
        _logger = logger;
    }

    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var (status, title, detail) = exception switch
        {
            TechnocareSiteException site => (Normalize(site.StatusCode), "Website integration error", site.Message),
            ShopCartException cart => (StatusCodes.Status409Conflict, "Cart could not be updated", cart.Message),
            UnauthorizedAccessException => (StatusCodes.Status401Unauthorized, "Authentication required", "Please sign in again."),
            _ => (StatusCodes.Status500InternalServerError, "Unexpected server error", "Please try again later."),
        };

        if (status >= 500)
        {
            _logger.LogError(exception, "Unhandled request error. TraceId: {TraceId}", httpContext.TraceIdentifier);
        }
        else
        {
            _logger.LogWarning(exception, "Request rejected. TraceId: {TraceId}", httpContext.TraceIdentifier);
        }

        httpContext.Response.StatusCode = status;
        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = status,
            Title = title,
            Detail = detail,
            Instance = httpContext.Request.Path,
            Extensions = { ["traceId"] = httpContext.TraceIdentifier },
        }, cancellationToken);
        return true;
    }

    private static int Normalize(int statusCode) => statusCode switch
    {
        >= 400 and < 500 => statusCode,
        _ => (int) HttpStatusCode.BadGateway,
    };
}
