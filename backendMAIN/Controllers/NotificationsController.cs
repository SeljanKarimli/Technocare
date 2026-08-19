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

        [HttpPut("{id:length(24)}/read")] // PUT /api/notifications/{id}/read
        public async Task<IActionResult> MarkAsRead(string id)
        {
            var userId = GetUserIdFromToken();
            var success = await _notificationService.MarkNotificationAsReadAsync(id, userId);
            if (!success)
            {
                return NotFound(new { message = "Notification not found or not authorized to mark as read." });
            }
            return NoContent();
        }

        [HttpPost] // POST /api/notifications
        public async Task<IActionResult> SendNotification([FromBody] CreateNotificationRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }
            await _notificationService.CreateNotificationAsync(request);
            return CreatedAtAction(nameof(SendNotification), new { message = "Notification sent successfully." });
        }

        [HttpGet("all")] // GET /api/notifications/all
        public async Task<ActionResult<List<Notification>>> GetAllNotifications()
        {
            // Admin can view all notifications, regardless of userId
            var notifications = await _notificationService.GetUserNotificationsAsync(""); // Pass empty string to get all (including null userId)
            return Ok(notifications);
        }

        [HttpDelete("{id:length(24)}")] 
        public async Task<IActionResult> DeleteNotification(string id)
        {
            var success = await _notificationService.DeleteNotificationAsync(id);
            if (!success)
            {
                return NotFound(new { message = "Notification not found." });
            }
            return NoContent();
        }
    }
}
