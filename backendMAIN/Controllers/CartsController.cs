using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
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
    public async Task<IActionResult> GetCart([FromQuery] string userId)
    {
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
        catch (Exception ex)
        {
            return StatusCode(500, new
            {
                message = "GetCart failed",
                error = ex.Message,
                stack = ex.StackTrace
            });
        }
    }

    [HttpPost]
    public async Task<IActionResult> AddItem([FromQuery] string userId, [FromBody] AddToCartRequest request)
    {
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
        catch (Exception ex)
        {
            // TEMP debug: Flutter konsolda konkret error görünsün deyə
            return StatusCode(500, new
            {
                message = "AddItem failed",
                error = ex.Message,
                stack = ex.StackTrace
            });
        }
    }




    [HttpPut("{productId}")]
    public async Task<IActionResult> UpdateItem(
        string productId,
        [FromQuery] string userId,
        [FromBody] UpdateCartItemRequest request)
    {
        var user = await _userService.GetByIdAsync(userId);
        if (user == null || string.IsNullOrEmpty(user.CartId))
            return NotFound(new { message = "User or cart not found." });

        var updated = await _cartService.UpdateItemQuantityAsync(user.CartId, productId, request);

        if (updated == null)
            return NotFound(new { message = "Item not found in cart." });

        return Ok(updated);
    }

    [HttpDelete("{productId}")]
    public async Task<IActionResult> RemoveItem(string productId, [FromQuery] string userId)
    {
        var user = await _userService.GetByIdAsync(userId);
        if (user == null || string.IsNullOrEmpty(user.CartId))
            return NotFound(new { message = "User or cart not found." });

        var ok = await _cartService.RemoveItemAsync(user.CartId, productId);

        if (!ok) return NotFound(new { message = "Item not found in cart." });
        return NoContent();
    }

    [HttpDelete("clear")]
    public async Task<IActionResult> ClearCart([FromQuery] string userId)
    {
        var user = await _userService.GetByIdAsync(userId);
        if (user == null || string.IsNullOrEmpty(user.CartId))
            return NotFound(new { message = "User or cart not found." });

        var ok = await _cartService.ClearCartAsync(user.CartId);

        if (!ok) return NotFound(new { message = "Cart not found." });

        return NoContent();
    }
}
