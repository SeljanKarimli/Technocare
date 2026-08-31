using System.Security.Claims;
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers;

[ApiController]
[Route("api/v1/shop")]
public sealed class ShopController : ControllerBase
{
    private readonly ITechnocareSiteClient _siteClient;
    private readonly ShopCartService _cartService;

    public ShopController(ITechnocareSiteClient siteClient, ShopCartService cartService)
    {
        _siteClient = siteClient;
        _cartService = cartService;
    }

    [HttpGet("products")]
    [AllowAnonymous]
    public async Task<ActionResult<PagedShopProductsResponse>> Products(CancellationToken cancellationToken)
    {
        return Ok(await _siteClient.GetProductsAsync(Request.QueryString.Value ?? string.Empty, cancellationToken));
    }

    [HttpGet("products/{id:long}")]
    [AllowAnonymous]
    public async Task<ActionResult<ShopProductDto>> Product(long id, CancellationToken cancellationToken)
    {
        return Ok(await _siteClient.GetProductAsync(id, cancellationToken));
    }

    [HttpGet("categories")]
    [AllowAnonymous]
    public async Task<ActionResult<ShopTaxonomyResponse>> Categories(CancellationToken cancellationToken)
    {
        return Ok(await _siteClient.GetCategoriesAsync(cancellationToken));
    }

    [HttpGet("brands")]
    [AllowAnonymous]
    public async Task<ActionResult<ShopTaxonomyResponse>> Brands(CancellationToken cancellationToken)
    {
        return Ok(await _siteClient.GetBrandsAsync(cancellationToken));
    }

    [HttpGet("cart")]
    [Authorize]
    public async Task<ActionResult<ShopCartDto>> Cart(CancellationToken cancellationToken)
    {
        return Ok(await _cartService.GetAsync(UserId(), cancellationToken));
    }

    [HttpPost("cart/items")]
    [Authorize]
    public async Task<ActionResult<ShopCartDto>> AddCartItem(AddShopCartItemRequest request, CancellationToken cancellationToken)
    {
        return Ok(await _cartService.AddAsync(UserId(), request.ProductId, request.Quantity, cancellationToken));
    }

    [HttpPatch("cart/items/{productId:long}")]
    [Authorize]
    public async Task<ActionResult<ShopCartDto>> UpdateCartItem(long productId, UpdateShopCartItemRequest request, CancellationToken cancellationToken)
    {
        return Ok(await _cartService.UpdateAsync(UserId(), productId, request.Quantity, cancellationToken));
    }

    [HttpDelete("cart/items/{productId:long}")]
    [Authorize]
    public async Task<ActionResult<ShopCartDto>> RemoveCartItem(long productId, CancellationToken cancellationToken)
    {
        return Ok(await _cartService.RemoveAsync(UserId(), productId, cancellationToken));
    }

    [HttpDelete("cart")]
    [Authorize]
    public async Task<IActionResult> ClearCart(CancellationToken cancellationToken)
    {
        await _cartService.ClearAsync(UserId(), cancellationToken);
        return NoContent();
    }

    [HttpPost("checkout-session")]
    [Authorize]
    public async Task<ActionResult<CheckoutSessionResponse>> CheckoutSession(CancellationToken cancellationToken)
    {
        var userId = UserId();
        var items = await _cartService.GetRawItemsAsync(userId, cancellationToken);
        if (items.Count == 0)
        {
            return BadRequest(new { message = "Səbət boşdur." });
        }
        var email = User.FindFirstValue(ClaimTypes.Email) ?? string.Empty;
        return Ok(await _siteClient.CreateCheckoutSessionAsync(userId, email, items, cancellationToken));
    }

    [HttpGet("orders")]
    [Authorize]
    public async Task<ActionResult<PagedShopOrdersResponse>> Orders([FromQuery] int page = 1, CancellationToken cancellationToken = default)
    {
        return Ok(await _siteClient.GetOrdersAsync(UserId(), Math.Max(1, page), cancellationToken));
    }

    private string UserId()
    {
        return User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new UnauthorizedAccessException("Authenticated user identifier is missing.");
    }
}
