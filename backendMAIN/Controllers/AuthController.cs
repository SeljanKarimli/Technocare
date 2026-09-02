// Controllers/AuthController.cs    
using Microsoft.AspNetCore.Authorization; // For [Authorize] attribute
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims; // For getting user ID from token
using System.Threading.Tasks;
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.RateLimiting;
using System.ComponentModel.DataAnnotations;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")] // Base route for this controller: /api/auth
    [EnableRateLimiting("auth")]
    public class AuthController : ControllerBase
    {
        private readonly UserService _userService;

        public AuthController(UserService userService)
        {
            _userService = userService;
        }

        [HttpPost("register")]
        [AllowAnonymous]
        public async Task<IActionResult> Register([FromBody] RegisterRequest request)
        {
            try
            {
                if (!ModelState.IsValid)
                    return BadRequest(ModelState);

                var userResponse = await _userService.RegisterAsync(request);

                if (userResponse == null)
                    return Conflict(new { message = "Bu email artıq qeydiyyatdan keçib." });

                return Ok(new { message = "Qeydiyyat tamamlandı. Email təsdiq kodunu yoxlayın." });
            }
            catch (Exception)
            {
                return StatusCode(500, new { message = "Qeydiyyatı tamamlamaq mümkün olmadı." });
            }
        }


        [HttpPost("login")] // POST /api/auth/login
        [AllowAnonymous] // Allow unauthenticated access
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            var userResponse = await _userService.LoginAsync(request);

            if (userResponse == null)
            {
                return Unauthorized(new { message = "Email və ya şifrə yanlışdır." }); // 401 Unauthorized
            }

            if (!userResponse.EmailVerified)
            {
                // This message now explicitly mentions checking email for verification, and suggests resending.
                return StatusCode(403, new { message = "Email təsdiqlənməyib. Gələn kodu daxil edin və ya yeni kod istəyin." }); // 403 Forbidden
            }

            return Ok(userResponse); // Contains user info and JWT token
        }

        [HttpPost("forgot-password")] // POST /api/auth/forgot-password
        [AllowAnonymous]
        public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            // Always return success to avoid exposing valid emails, even if user doesn't exist
            await _userService.SendPasswordResetEmailAsync(request.Email);
            return Ok(new { message = "Hesab mövcuddursa, şifrə bərpa kodu emailə göndərildi." });
        }

        [HttpDelete("delete-my-account")]
        [Authorize]
        public async Task<IActionResult> DeleteMyAccount()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized();
            }
            return await _userService.DeleteAsync(userId) ? NoContent() : NotFound();
        }

        
        [HttpPost("reset-password")] // POST /api/auth/reset-password
        [AllowAnonymous]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            var success = await _userService.ResetPasswordAsync(request);

            if (success)
            {
                return Ok(new { message = "Şifrə uğurla yeniləndi." });
            }
            return BadRequest(new { message = "Email və ya bərpa kodu yanlışdır, yaxud kodun vaxtı bitib." });
        }

        [HttpPost("resend-verification")] // POST /api/auth/resend-verification
        [AllowAnonymous]
        public async Task<IActionResult> ResendVerificationEmail([FromBody] ForgotPasswordRequest request) // Reusing ForgotPasswordRequest DTO for email
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            // Similar to forgot-password, return success even if email not found or already verified
            // to avoid exposing user existence/status.
            await _userService.ResendVerificationEmailAsync(request.Email);
            return Ok(new { message = "Hesab təsdiqlənməyibsə, yeni kod göndərildi." });
        }

        [HttpPost("resend-code")] // POST /api/auth/resend-code
        [AllowAnonymous]
        public async Task<IActionResult> ResendVerificationCode([FromBody] ForgotPasswordRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }
            await _userService.ResendVerificationEmailAsync(request.Email);
            return Ok(new { message = "Hesab təsdiqlənməyibsə, yeni kod göndərildi." });
        }

        [HttpGet("{id}")] // GET /api/auth/{id}
        [Authorize] // Only authenticated users or admins can access their own profile or others if admin
        public async Task<IActionResult> GetUserById(string id)
        {
            // Ensure the authenticated user can only view their own profile, unless they are an Admin
            var userIdFromToken = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            var userRoleFromToken = User.FindFirst(ClaimTypes.Role)?.Value;

            if (userIdFromToken != id && userRoleFromToken != "Admin")
            {
                return Forbid(); // 403 Forbidden
            }

            var user = await _userService.GetByIdAsync(id);
            if (user == null)
            {
                return NotFound();
            }

            // Return a UserResponse to avoid sending password hash
            return Ok(new UserResponse
            {
                Id = user.Id!,
                Name = user.Name,
                Email = user.Email,
                Phone = user.Phone,
                Role = user.Role,
                EmailVerified = user.EmailVerified
            });
        }

        
        [HttpPost("verify-email")] // POST /api/auth/verify-email
        [AllowAnonymous]
        public async Task<IActionResult> VerifyEmail([FromBody] VerifyEmailRequest request)
        {
            if (await _userService.VerifyEmailAsync(request.Email, request.Code))
            {
                return Ok(new { message = "Email uğurla təsdiqləndi." });
            }
            return BadRequest(new { message = "Təsdiq kodu yanlışdır və ya vaxtı bitib." });
        }
        // GET /api/auth/users
        [HttpGet("users")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetAllUsers()
        {
            var users = await _userService.GetAllAsync();

            var response = users.Select(user => new UserResponse
            {
                Id = user.Id!,
                Name = user.Name,
                Email = user.Email,
                Phone = user.Phone,
                Role = user.Role,
                EmailVerified = user.EmailVerified
            });

            return Ok(response);
        }

    }
}
