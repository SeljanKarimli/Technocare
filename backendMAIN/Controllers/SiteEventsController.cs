using System.Text.Json;
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace backend.Controllers;

[ApiController]
[Route("api/v1/site-events")]
[AllowAnonymous]
[EnableRateLimiting("site-events")]
public sealed class SiteEventsController(
    SiteEventSignatureVerifier signatureVerifier,
    NotificationService notifications) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Receive(CancellationToken cancellationToken)
    {
        using var reader = new StreamReader(Request.Body);
        var body = await reader.ReadToEndAsync(cancellationToken);
        if (!signatureVerifier.Verify(
                body,
                Request.Headers["X-Technocare-Timestamp"].FirstOrDefault(),
                Request.Headers["X-Technocare-Nonce"].FirstOrDefault(),
                Request.Headers["X-Technocare-Signature"].FirstOrDefault()))
        {
            return Unauthorized(new { message = "Sorğunun imzası etibarsızdır." });
        }

        SiteUpdateEvent? siteEvent;
        try
        {
            siteEvent = JsonSerializer.Deserialize<SiteUpdateEvent>(body, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        }
        catch (JsonException)
        {
            return BadRequest(new { message = "Sorğunun məlumatı düzgün deyil." });
        }
        if (siteEvent is null || !TryValidateModel(siteEvent))
        {
            return ValidationProblem(ModelState);
        }

        var created = await notifications.CreateSiteUpdateAsync(siteEvent, cancellationToken);
        return created is null
            ? Ok(new { accepted = true, duplicate = true })
            : Accepted(new { accepted = true, notificationId = created.Id });
    }
}
