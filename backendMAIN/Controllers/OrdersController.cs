// Controllers/OrdersController.cs
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/internal/legacy/orders")]
    [Authorize(Roles = "Admin")]
    [ApiExplorerSettings(IgnoreApi = true)]
    public class OrdersController : ControllerBase
    {
        private readonly OrderService _orderService;

        public OrdersController(OrderService orderService)
        {
            _orderService = orderService;
        }

        // POST /api/orders
        [HttpPost]
        public async Task<IActionResult> CreateOrder([FromBody] CreateOrderRequest request)
        {
            request.UserId = CurrentUserId();
            if (!ModelState.IsValid) return BadRequest(ModelState);

            try
            {
                var order = await _orderService.CreateOrderFromCartAsync(request.UserId, request);

                if (order == null)
                    return BadRequest(new { message = "Order could not be created. Check your request data." });

                return CreatedAtAction(nameof(GetOrderById), new { id = order.Id }, order);
            }
            catch (Exception)
            {
                return BadRequest(new { message = "Order could not be created." });
            }
        }

        // GET /api/orders/my-orders?userId=...
        [HttpGet("my-orders")]
        public async Task<ActionResult<List<Order>>> GetUserOrders()
        {
            var userId = CurrentUserId();

            try
            {
                var orders = await _orderService.GetOrdersByUserIdAsync(userId);
                return Ok(orders);
            }
            catch (Exception)
            {
                return StatusCode(500, new { message = "Orders could not be loaded." });
            }
        }

        // GET /api/orders/{id}
        [HttpGet("{id:length(24)}")]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<Order>> GetOrderById(string id)
        {
            var order = await _orderService.GetOrderByIdAsync(id);
            return order is null ? NotFound() : Ok(order);
        }

        // GET /api/orders
        [HttpGet]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<List<Order>>> GetAllOrders()
        {
            var orders = await _orderService.GetAllOrdersAsync();
            return Ok(orders);
        }

        // PUT /api/orders/{id}/status
        [HttpPut("{id:length(24)}/status")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> UpdateOrderStatus(string id, [FromBody] UpdateOrderStatusRequest request)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var ok = await _orderService.UpdateOrderStatusAsync(id, request);
            return ok ? NoContent() : NotFound();
        }

        // DELETE /api/orders/{id}
        [HttpDelete("{id:length(24)}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> DeleteOrder(string id)
        {
            var ok = await _orderService.DeleteOrderAsync(id);
            return ok ? NoContent() : NotFound();
        }

        private string CurrentUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new UnauthorizedAccessException("Authenticated user identifier is missing.");
    }
}
