// Controllers/AuthController.cs    
using Microsoft.AspNetCore.Authorization; // For [Authorize] attribute
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims; // For getting user ID from token
using System.Threading.Tasks;
using backend.Models;
using backend.Services;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")] // Base route for this controller: /api/auth
    public class AuthController : ControllerBase
    {
        private readonly UserService _userService;
        private readonly EmailService _emailService; // Add EmailService for sending emails

        public AuthController(UserService userService, EmailService emailService)
        {
            _userService = userService;
            _emailService = emailService;
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
                    return Conflict(new { message = "Email already registered." });

                return Ok(new { message = "Registration successful. Please check your email to verify your account." });
            }
            catch (Exception ex)
            {
                Console.WriteLine("REGISTER ERROR: " + ex); // IMPORTANT
                return StatusCode(500, new { message = "Internal Server Error", error = ex.Message });
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
                return Unauthorized(new { message = "Invalid email or password." }); // 401 Unauthorized
            }

            if (!userResponse.EmailVerified)
            {
                // This message now explicitly mentions checking email for verification, and suggests resending.
                return StatusCode(403, new { message = "Email not verified. Please check your inbox for a verification link, or use the /api/auth/resend-verification endpoint if needed." }); // 403 Forbidden
            }

            return Ok(userResponse); // Contains user info and JWT token
        }

        [HttpGet("verify-email")] // GET /api/auth/verify-email?email={email}&token={token}
        [AllowAnonymous]
        public async Task<IActionResult> VerifyEmail([FromQuery] string email, [FromQuery] string token)
        {
            var success = await _userService.VerifyEmailAsync(email, token);

            if (success)
            {
                return Ok(new { message = "Email verified successfully! You can now log in." });
            }
            return BadRequest(new { message = "Invalid verification link or email already verified." });
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
            return Ok(new { message = "A password reset link has been sent to your inbox." });
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
                return Ok(new { message = "Password has been reset successfully." });
            }
            return BadRequest(new { message = "Invalid or expired reset token, or email." });
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
            return Ok(new { message = "A new verification link has been sent to your inbox." });
        }

        [HttpPost("resend-code")] // POST /api/auth/resend-code
        [AllowAnonymous]
        public async Task<IActionResult> ResendVerificationCode([FromBody] ForgotPasswordRequest request)
        {
            var user = await _userService.GetByEmailAsync(request.Email);
            if (user == null || user.EmailVerified)
                return Ok(new { message = "If your account is unverified, a new code has been sent." });

            var code = new Random().Next(100000, 999999).ToString();
            user.EmailVerificationCode = code;
            user.EmailVerificationCodeExpires = DateTime.UtcNow.AddMinutes(10);
            await _userService.UpdateAsync(user);

            await _emailService.SendVerificationCodeEmail(user.Email, code);

            return Ok(new { message = "Verification code resent." });
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
            var user = await _userService.GetByEmailAsync(request.Email);
            if (user == null || user.EmailVerified)
                return BadRequest(new { message = "Invalid request." });

            if (user.EmailVerificationCode == request.Code &&
                user.EmailVerificationCodeExpires > DateTime.UtcNow)
            {
                user.EmailVerified = true;
                user.EmailVerificationCode = null;
                user.EmailVerificationCodeExpires = null;
                await _userService.UpdateAsync(user);
                return Ok(new { message = "Email verified successfully." });
            }
            return BadRequest(new { message = "Invalid or expired code." });
        }
        // GET /api/auth/users
        [HttpGet("users")]
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



        public class VerifyEmailRequest
        {
            public string Email { get; set; }
            public string Code { get; set; }
        }
    }
}