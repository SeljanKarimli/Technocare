using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MongoDB.Bson;
using System.Security.Claims;

namespace backend.Controllers;

[ApiController]
[Route("api/internal/legacy/carts")]
[Authorize(Roles = "Admin")]
[ApiExplorerSettings(IgnoreApi = true)]
public class CartsController : ControllerBase
{
    private readonly CartService _cartService;
    private readonly UserService _userService;

    public CartsController(CartService cartService, UserService userService)
    {
        _cartService = cartService;
        _userService = userService;
    }
    [HttpGet]
    public async Task<IActionResult> GetCart()
    {
        var userId = CurrentUserId();
        try
        {
            var user = await _userService.GetByIdAsync(userId);
            if (user == null || string.IsNullOrEmpty(user.CartId))
                return NotFound(new { message = "User or cart not found." });

            var cart = await _cartService.GetCartByIdAsync(user.CartId);
            if (cart == null)
                return NotFound(new { message = "Cart not found." });

            return Ok(cart);
        }
        catch (Exception)
        {
            return StatusCode(500, new
            {
                message = "Cart could not be loaded."
            });
        }
    }

    [HttpPost]
    public async Task<IActionResult> AddItem([FromBody] AddToCartRequest request)
    {
        var userId = CurrentUserId();
        try
        {
            var user = await _userService.GetByIdAsync(userId);
            if (user == null)
                return NotFound(new { message = "User not found." });

            if (string.IsNullOrEmpty(user.CartId))
            {
                user.CartId = ObjectId.GenerateNewId().ToString();
                await _userService.UpdateAsync(user);
            }

            var updated = await _cartService.AddOrUpdateItemAsync(user.CartId, request);
            return Ok(updated);
        }
        catch (Exception)
        {
            return StatusCode(500, new
            {
                message = "Cart could not be updated."
            });
        }
    }




    [HttpPut("{productId}")]
    public async Task<IActionResult> UpdateItem(
        string productId,
        [FromBody] UpdateCartItemRequest request)
    {
        var userId = CurrentUserId();
        var user = await _userService.GetByIdAsync(userId);
        if (user == null || string.IsNullOrEmpty(user.CartId))
            return NotFound(new { message = "User or cart not found." });

        var updated = await _cartService.UpdateItemQuantityAsync(user.CartId, productId, request);

        if (updated == null)
            return NotFound(new { message = "Item not found in cart." });

        return Ok(updated);
    }

    [HttpDelete("{productId}")]
    public async Task<IActionResult> RemoveItem(string productId)
    {
        var userId = CurrentUserId();
        var user = await _userService.GetByIdAsync(userId);
        if (user == null || string.IsNullOrEmpty(user.CartId))
            return NotFound(new { message = "User or cart not found." });

        var ok = await _cartService.RemoveItemAsync(user.CartId, productId);

        if (!ok) return NotFound(new { message = "Item not found in cart." });
        return NoContent();
    }

    [HttpDelete("clear")]
    public async Task<IActionResult> ClearCart()
    {
        var userId = CurrentUserId();
        var user = await _userService.GetByIdAsync(userId);
        if (user == null || string.IsNullOrEmpty(user.CartId))
            return NotFound(new { message = "User or cart not found." });

        var ok = await _cartService.ClearCartAsync(user.CartId);

        if (!ok) return NotFound(new { message = "Cart not found." });

        return NoContent();
    }

    private string CurrentUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? throw new UnauthorizedAccessException("Authenticated user identifier is missing.");
}
