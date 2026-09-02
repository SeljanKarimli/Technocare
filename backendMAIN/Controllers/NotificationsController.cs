// Controllers/NotificationsController.cs
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using System.Threading.Tasks;
using backend.Models;
using backend.Services;
using System.Collections.Generic;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")] // Base route: /api/notifications
    [Authorize]
    public class NotificationsController : ControllerBase
    {
        private readonly NotificationService _notificationService;

        public NotificationsController(NotificationService notificationService)
        {
            _notificationService = notificationService;
        }

        private string GetUserIdFromToken()
        {
            return User.FindFirst(ClaimTypes.NameIdentifier)?.Value!;
        }

        [HttpGet("my-notifications")] // GET /api/notifications/my-notifications
        public async Task<ActionResult<List<Notification>>> GetMyNotifications()
        {
            var userId = GetUserIdFromToken();
            var notifications = await _notificationService.GetUserNotificationsAsync(userId);
            return Ok(notifications);
        }

        [HttpGet("public")]
        [AllowAnonymous]
        public async Task<ActionResult<List<Notification>>> GetPublicNotifications([FromQuery] int limit = 50)
        {
            var notifications = await _notificationService.GetPublicNotificationsAsync(limit, HttpContext.RequestAborted);
            return Ok(notifications);
        }

        [HttpPut("{id:length(24)}/read")] // PUT /api/notifications/{id}/read
        public async Task<IActionResult> MarkAsRead(string id)
        {
            var userId = GetUserIdFromToken();
            var success = await _notificationService.MarkNotificationAsReadAsync(id, userId);
            if (!success)
            {
                return NotFound(new { message = "Bildiriş tapılmadı və ya bu əməliyyata icazəniz yoxdur." });
            }
            return NoContent();
        }

        [HttpPost] // POST /api/notifications
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> SendNotification([FromBody] CreateNotificationRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }
            await _notificationService.CreateNotificationAsync(request);
            return CreatedAtAction(nameof(SendNotification), new { message = "Bildiriş uğurla göndərildi." });
        }

        [HttpGet("all")] // GET /api/notifications/all
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<List<Notification>>> GetAllNotifications()
        {
            var notifications = await _notificationService.GetAllNotificationsAsync(HttpContext.RequestAborted);
            return Ok(notifications);
        }

        [HttpDelete("{id:length(24)}")] 
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> DeleteNotification(string id)
        {
            var success = await _notificationService.DeleteNotificationAsync(id);
            if (!success)
            {
                return NotFound(new { message = "Bildiriş tapılmadı." });
            }
            return NoContent();
        }
    }
}
