using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using backend.Models;
using backend.Services;
using System.Security.Claims;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.RateLimiting;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AdminController : ControllerBase
    {
        private readonly UserService _userService;
        public AdminController(UserService userService)
        {
            _userService = userService;
        }

        [HttpPost("login")]
        [AllowAnonymous]
        [EnableRateLimiting("auth")]
        public async Task<IActionResult> AdminLogin([FromBody] AdminLoginRequest request)
        {
            var response = await _userService.LoginAsync(new LoginRequest
            {
                Email = request.Email,
                Password = request.Password,
            });
            if (response is null || !response.EmailVerified || response.Role != "Admin" || string.IsNullOrWhiteSpace(response.Token))
            {
                return Unauthorized(new { message = "Admin məlumatları yanlışdır." });
            }

            return Ok(new AdminLoginResponse
            {
                Token = response.Token,
                User = new AdminUserInfo
                {
                    Id = response.Id,
                    Name = response.Name,
                    Email = response.Email,
                    Role = response.Role,
                },
            });
        }

        [HttpGet("stats")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetAdminStats()
        {
            try
            {
                var allUsers = await _userService.GetAllAsync();
                var totalUsers = allUsers.Count;
                var verifiedUsers = allUsers.Count(u => u.EmailVerified);
                var adminUsers = allUsers.Count(u => u.Role == "Admin");

                return Ok(new AdminStats
                {
                    TotalUsers = totalUsers,
                    VerifiedUsers = verifiedUsers,
                    AdminUsers = adminUsers,
                    PendingVerifications = totalUsers - verifiedUsers
                });
            }
            catch (Exception)
            {
                return StatusCode(500, new { message = "Failed to retrieve stats" });
            }
        }

        [HttpPost("make-admin")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> MakeAdmin([FromBody] MakeAdminRequest request)
        {
            var user = await _userService.GetByEmailAsync(request.Email);
            if (user == null)
            {
                return NotFound(new { message = "User not found" });
            }

            user.Role = "Admin";
            await _userService.UpdateAsync(user);

            return Ok(new { message = "User promoted to admin successfully" });
        }

        [HttpPost("remove-admin")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> RemoveAdmin([FromBody] MakeAdminRequest request)
        {
            var user = await _userService.GetByEmailAsync(request.Email);
            if (user == null)
            {
                return NotFound(new { message = "User not found" });
            }

            // Prevent removing the last admin
            var allUsers = await _userService.GetAllAsync();
            var adminCount = allUsers.Count(u => u.Role == "Admin");
            if (adminCount <= 1 && user.Role == "Admin")
            {
                return BadRequest(new { message = "Cannot remove the last admin account" });
            }

            user.Role = "User";
            await _userService.UpdateAsync(user);

            return Ok(new { message = "Admin privileges removed successfully" });
        }
    }

    // DTOs
    public class AdminLoginRequest
    {
        [Required, EmailAddress, StringLength(254)]
        public string Email { get; set; } = null!;

        [Required, StringLength(64, MinimumLength = 1)]
        public string Password { get; set; } = null!;
    }

    public class AdminLoginResponse
    {
        public string Token { get; set; } = null!;
        public AdminUserInfo User { get; set; } = null!;
    }

    public class AdminUserInfo
    {
        public string Id { get; set; } = null!;
        public string Name { get; set; } = null!;
        public string Email { get; set; } = null!;
        public string Role { get; set; } = null!;
    }

    public class AdminStats
    {
        public int TotalUsers { get; set; }
        public int VerifiedUsers { get; set; }
        public int AdminUsers { get; set; }
        public int PendingVerifications { get; set; }
    }
}
