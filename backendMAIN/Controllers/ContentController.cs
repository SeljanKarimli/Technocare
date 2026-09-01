using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers;

[ApiController]
[Route("api/v1/content")]
public sealed class ContentController : ControllerBase
{
    private readonly ITechnocareSiteClient _siteClient;

    public ContentController(ITechnocareSiteClient siteClient)
    {
        _siteClient = siteClient;
    }

    [HttpGet("home")]
    [AllowAnonymous]
    [ResponseCache(Duration = 300, Location = ResponseCacheLocation.Any)]
    public async Task<ActionResult<HomeContentResponse>> Home(CancellationToken cancellationToken)
    {
        return Ok(await _siteClient.GetHomeAsync(cancellationToken));
    }

    [HttpGet("projects")]
    [AllowAnonymous]
    [ResponseCache(Duration = 300, Location = ResponseCacheLocation.Any)]
    public async Task<ActionResult<PagedSiteProjectsResponse>> Projects(
        [FromQuery] string q = "",
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 12,
        CancellationToken cancellationToken = default)
    {
        return Ok(await _siteClient.GetProjectsAsync(q ?? string.Empty, page, pageSize, cancellationToken));
    }

    [HttpGet("services")]
    [AllowAnonymous]
    [ResponseCache(Duration = 300, Location = ResponseCacheLocation.Any)]
    public async Task<ActionResult<SiteContentCollectionResponse>> Services(CancellationToken cancellationToken)
    {
        return Ok(await _siteClient.GetServicesAsync(cancellationToken));
    }

    [HttpGet("education")]
    [AllowAnonymous]
    [ResponseCache(Duration = 300, Location = ResponseCacheLocation.Any)]
    public async Task<ActionResult<SiteContentCollectionResponse>> Education(CancellationToken cancellationToken)
    {
        return Ok(await _siteClient.GetEducationAsync(cancellationToken));
    }
}
