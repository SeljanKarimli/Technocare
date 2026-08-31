using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using backend.Models;
using backend.Services;
using System.Security.Claims;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;
using System.Text;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AdminController : ControllerBase
    {
        private readonly UserService _userService;
        private readonly TokenService _tokenService;
        private readonly string _adminEmail;
        private readonly string _adminPassword;

        public AdminController(UserService userService, IConfiguration configuration, TokenService tokenService)
        {
            _userService = userService;
            _tokenService = tokenService;
            _adminEmail = configuration["AdminSettings:Email"]
                ?? throw new InvalidOperationException("AdminSettings:Email is not configured.");
            _adminPassword = configuration["AdminSettings:Password"]
                ?? throw new InvalidOperationException("AdminSettings:Password is not configured.");
        }

        [HttpPost("login")]
        [AllowAnonymous]
        public async Task<IActionResult> AdminLogin([FromBody] AdminLoginRequest request)
        {
            if (!string.Equals(request.Email, _adminEmail, StringComparison.OrdinalIgnoreCase) ||
                request.Password != _adminPassword)
            {
                return Unauthorized(new { message = "Invalid admin credentials" });
            }

            // Check if admin user exists in database, if not create it
            var adminUser = await _userService.GetByEmailAsync(_adminEmail);

            if (adminUser == null)
            {
                // Create admin user
                var registerRequest = new RegisterRequest
                {
                    Name = "Admin",
                    Email = _adminEmail,
                    Password = _adminPassword,
                    Phone = "+994500000000"
                };

                var userResponse = await _userService.RegisterAsync(registerRequest);
                if (userResponse != null)
                {
                    adminUser = await _userService.GetByEmailAsync(_adminEmail);
                    // Verify email automatically for admin
                    if (adminUser != null)
                    {
                        adminUser.EmailVerified = true;
                        adminUser.Role = "Admin";
                        await _userService.UpdateAsync(adminUser);
                    }
                }
            }
            else
            {
                // Ensure existing user has admin role and verified email
                if (adminUser.Role != "Admin" || !adminUser.EmailVerified)
                {
                    adminUser.Role = "Admin";
                    adminUser.EmailVerified = true;
                    await _userService.UpdateAsync(adminUser);
                }
            }

            // Generate JWT token
            if (adminUser != null)
            {
                var token = _tokenService.GenerateJwtToken(adminUser);

                return Ok(new AdminLoginResponse
                {
                    Token = token,
                    User = new AdminUserInfo
                    {
                        Id = adminUser.Id!,
                        Name = adminUser.Name,
                        Email = adminUser.Email,
                        Role = "Admin"
                    }
                });
            }

            return StatusCode(500, new { message = "Failed to create admin session" });
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
            if (adminCount <= 1 && string.Equals(user.Email, _adminEmail, StringComparison.OrdinalIgnoreCase))
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
        public string Email { get; set; } = null!;
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
