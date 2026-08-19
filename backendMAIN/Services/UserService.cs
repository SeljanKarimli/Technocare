// Services/UserService.cs
using backend.Models;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens; // For JWT signing credentials
using MongoDB.Driver;
using Org.BouncyCastle.Crypto.Generators;
using System;
using System.IdentityModel.Tokens.Jwt; // For JWT token
using System.Linq; // For LINQ operations
using System.Security.Claims; // For JWT claims
using System.Security.Cryptography; // For password hashing
using System.Text; // For encoding
using System.Threading.Tasks;
namespace backend.Services;
public class UserService
{
    private readonly IMongoCollection<User> _usersCollection;
    private readonly IMongoCollection<Cart> _cartsCollection;
    private readonly IConfiguration _configuration;
    private readonly EmailService _emailService;
    private readonly TokenService _tokenService;
    private readonly JwtSettings _jwtSettings;

    public UserService(
        IOptions<MongoDbSettings> mongoDbSettings,
        IOptions<JwtSettings> jwtSettings,
        EmailService emailService,
        TokenService tokenService,
        IConfiguration configuration)
    {
        var mongoClient = new MongoClient(mongoDbSettings.Value.ConnectionString);
        var mongoDatabase = mongoClient.GetDatabase(mongoDbSettings.Value.DatabaseName);
        _usersCollection = mongoDatabase.GetCollection<User>(mongoDbSettings.Value.UsersCollectionName);
        _cartsCollection = mongoDatabase.GetCollection<Cart>("Carts");
        _emailService = emailService;
        _tokenService = tokenService;
        _jwtSettings = jwtSettings.Value;
        _configuration = configuration;
    }

    // Hashes a password using SHA256
    // In UserService.cs
    public string HashPassword(string password)
    {
        // Generate salt automatically and hash the password
        return BCrypt.Net.BCrypt.HashPassword(password, workFactor: 12);
    }
    public async Task<List<User>> GetAllAsync()
    {
        return await _usersCollection.Find(_ => true).ToListAsync();
    }

    public bool VerifyPassword(string inputPassword, string storedHash)
    {
        try
        {
            return BCrypt.Net.BCrypt.Verify(inputPassword, storedHash);
        }
        catch (BCrypt.Net.SaltParseException)
        {
            // Handle cases where the hash is invalid
            return false;
        }
    }
    public string GenerateJwtToken(User user)
    {
        return _tokenService.GenerateJwtToken(user);
    }

    // Add this method
    public async Task<User?> GetByEmailAsync(string email)
    {
        return await _usersCollection.Find(u => u.Email == email).FirstOrDefaultAsync();
    }
    // Generates a random token for email verification or password reset
    private string GenerateRandomToken()
    {
        // Using GUID is simple and generally unique enough for tokens
        return Guid.NewGuid().ToString("N");
    }



    // Update user role
    public async Task<bool> UpdateUserRoleAsync(string id, string newRole)
    {
        var update = Builders<User>.Update.Set(u => u.Role, newRole);
        var result = await _usersCollection.UpdateOneAsync(u => u.Id == id, update);
        return result.ModifiedCount > 0;
    }
    // Logs in a user
    public string GenerateAdminToken(User user)
    {
        if (user == null) throw new ArgumentNullException(nameof(user));

        // Get configuration with null checks
        var secret = _configuration["JwtSettings:Secret"]
            ?? throw new InvalidOperationException("JWT Secret not configured");
        var issuer = _configuration["JwtSettings:Issuer"] ?? "your-app-name";
        var audience = _configuration["JwtSettings:Audience"] ?? "your-app-name";

        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.ASCII.GetBytes(secret);

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(new[]
            {
            new Claim(ClaimTypes.NameIdentifier, user.Id),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim(ClaimTypes.Role, user.Role ?? "User")
        }),
            Expires = DateTime.UtcNow.AddMinutes(
                _configuration.GetValue<int>("JwtSettings:ExpiryInMinutes", 1440)),
            Issuer = issuer,
            Audience = audience,
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(key),
                SecurityAlgorithms.HmacSha256Signature)
        };

        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }

    public async Task<UserResponse?> RegisterAsync(RegisterRequest request)
    {
        var normalizedEmail = request.Email.ToLowerInvariant();
        var existingUser = await _usersCollection.Find(u => u.Email.ToLower() == normalizedEmail).FirstOrDefaultAsync();
        if (existingUser != null)
            return null;


        var code = new Random().Next(100000, 999999).ToString();


        // FIRST: Create empty cart for the new user
        var newCart = new Cart { Items = new List<CartItem>() };
        await _cartsCollection.InsertOneAsync(newCart);


        var user = new User
        {
            Name = request.Name,
            Email = normalizedEmail,
            PasswordHash = HashPassword(request.Password),
            Phone = request.Phone,
            EmailVerified = false,
            EmailVerificationCode = code,
            EmailVerificationCodeExpires = DateTime.UtcNow.AddMinutes(10),
            Role = "User",
            CartId = newCart.Id // ★ Assign newly created cart to user
        };


        await _usersCollection.InsertOneAsync(user);


        await _emailService.SendVerificationCodeEmail(user.Email, code);


        return new UserResponse
        {
            Id = user.Id!,
            Name = user.Name,
            Email = user.Email,
            Phone = user.Phone,
            Role = user.Role,
            EmailVerified = user.EmailVerified,
            CartId = user.CartId // ★ RETURN CART ID
        };
    }

    public async Task<bool> VerifyEmailAsync(string email, string code)
    {
        var now = DateTime.UtcNow;

        var user = await _usersCollection
            .Find(u => u.Email == email &&
                       u.EmailVerificationCode == code &&
                       u.EmailVerificationCodeExpires > now)
            .FirstOrDefaultAsync();

        if (user == null)
            return false;

        var update = Builders<User>.Update
            .Set(u => u.EmailVerified, true)
            .Set(u => u.EmailVerificationCode, null)
            .Set(u => u.EmailVerificationCodeExpires, null);

        var result = await _usersCollection.UpdateOneAsync(u => u.Id == user.Id, update);

        return result.ModifiedCount > 0;
    }

    // Login user — UPDATED TO ALSO RETURN CART ID
    public async Task<UserResponse?> LoginAsync(LoginRequest request)
    {
        // Find user by email
        var user = await _usersCollection
            .Find(u => u.Email == request.Email)
            .FirstOrDefaultAsync();

        // Invalid email or password
        if (user == null || !VerifyPassword(request.Password, user.PasswordHash))
            return null;

        // If email is not verified, return a response without token
        if (!user.EmailVerified)
        {
            return new UserResponse
            {
                Id = user.Id!,
                Name = user.Name,
                Email = user.Email,
                Phone = user.Phone,
                Role = user.Role,
                EmailVerified = false,
                CartId = user.CartId
                // Token is null here on purpose
            };
        }

        // Email is verified → generate JWT token
        var token = _tokenService.GenerateJwtToken(user);

        return new UserResponse
        {
            Id = user.Id!,
            Name = user.Name,
            Email = user.Email,
            Phone = user.Phone,
            Role = user.Role,
            EmailVerified = true,
            Token = token,
            CartId = user.CartId
        };
    }

    // Sends a password reset email
    public async Task<bool> SendPasswordResetEmailAsync(string email)
    {
        var user = await _usersCollection.Find(u => u.Email == email).FirstOrDefaultAsync();

        if (user == null)
        {
            // For security reasons, always return true even if user not found
            // to avoid exposing whether an email is registered or not.
            return true;
        }

        var resetToken = GenerateRandomToken();
        // Set expiry for 1 hour from now
        var resetTokenExpiry = DateTime.UtcNow.AddHours(1);

        var update = Builders<User>.Update
            .Set(u => u.ResetToken, resetToken)
            .Set(u => u.ResetTokenExpiry, resetTokenExpiry);

        await _usersCollection.UpdateOneAsync(u => u.Id == user.Id, update);

        string emailBody = $"You requested a password reset. Here is your reset token: {resetToken}. " +
                           "This token will expire in 1 hour. Use it in the app to reset your password.";

        if (!string.IsNullOrEmpty(user.Email))
        {
            await _emailService.SendEmailAsync(user.Email, "Password Reset Request for Technocare", emailBody);
        }
        else
        {
            Console.WriteLine($"Warning: User email is null or empty for password reset for user ID {user.Id}. Skipping email sending.");
        }

        return true;
    }

    /// <summary>
    /// Resends a verification email to an unverified user.
    /// </summary>
    /// <param name="email">The email of the user to resend verification to.</param>
    /// <returns>True if the email was sent (or user doesn't exist/is already verified and no action taken), false on explicit error (not authentication).</returns>
    public async Task<bool> ResendVerificationEmailAsync(string email)
    {
        var user = await _usersCollection.Find(u => u.Email == email).FirstOrDefaultAsync();

        if (user == null || user.EmailVerified)
        {
            // For security reasons, return true if user not found or already verified,
            // to avoid exposing whether an email is registered/verified.
            return true;
        }

        // Generate a new verification token
        user.VerificationToken = GenerateRandomToken();
        var update = Builders<User>.Update.Set(u => u.VerificationToken, user.VerificationToken);
        await _usersCollection.UpdateOneAsync(u => u.Id == user.Id, update);

        // Send new verification email
        string verificationLink = $"http://localhost:5001/api/auth/verify-email?email={user.Email}&token={user.VerificationToken}"; // Adjust URL for production
        string emailBody = $"A new verification link for your Technocare account has been requested. Please verify your email by clicking on this link: <a href=\"{verificationLink}\">Verify Email</a>";

        if (!string.IsNullOrEmpty(user.Email))
        {
            await _emailService.SendEmailAsync(user.Email, "Resend Verification Link for Technocare", emailBody);
        }
        else
        {
            Console.WriteLine($"Warning: User email is null or empty for resend verification for user ID {user.Id}. Skipping email sending.");
        }
        return true;
    }


    // Resets user's password
    public async Task<bool> ResetPasswordAsync(ResetPasswordRequest request)
    {
        var user = await _usersCollection.Find(u => u.Email == request.Email && u.ResetToken == request.Token && u.ResetTokenExpiry > DateTime.UtcNow).FirstOrDefaultAsync();

        if (user == null)
        {
            return false; // Invalid email, token, or expired token
        }

        // Update password and clear reset token fields
        var update = Builders<User>.Update
            .Set(u => u.PasswordHash, HashPassword(request.NewPassword))
            .Unset(u => u.ResetToken)
            .Unset(u => u.ResetTokenExpiry);

        var result = await _usersCollection.UpdateOneAsync(u => u.Id == user.Id, update);

        return result.ModifiedCount > 0;
    }

    // Get user by ID (useful for profile display)
    public async Task<User?> GetByIdAsync(string id) =>
        await _usersCollection.Find(u => u.Id == id).FirstOrDefaultAsync();

    // Admin: Get all users
    public async Task<List<User>> GetAllUsersAsync() =>
        await _usersCollection.Find(_ => true).ToListAsync();

    // Admin: Delete user
    public async Task<bool> DeleteUserAsync(string id)
    {
        var result = await _usersCollection.DeleteOneAsync(u => u.Id == id);
        return result.DeletedCount > 0;
    }

    // Registers a new user with email verification code
    public async Task RegisterUserAsync(User user)
    {
        // ... existing user creation logic ...
        var code = new Random().Next(100000, 999999).ToString();
        user.EmailVerificationCode = code;
        user.EmailVerificationCodeExpires = DateTime.UtcNow.AddMinutes(10);
        user.EmailVerified = false;
        await _usersCollection.InsertOneAsync(user);

        await _emailService.SendVerificationCodeEmail(user.Email, code);
    }

    public async Task UpdateAsync(User user)
    {
        var filter = Builders<User>.Filter.Eq(u => u.Id, user.Id);
        await _usersCollection.ReplaceOneAsync(filter, user);
    }

    public async Task UpdateVerificationAsync(string userId, bool emailVerified, string? code, DateTime? expires)
    {
        var update = Builders<User>.Update
            .Set(u => u.EmailVerified, emailVerified)
            .Set(u => u.EmailVerificationCode, code)
            .Set(u => u.EmailVerificationCodeExpires, expires);

        await _usersCollection.UpdateOneAsync(u => u.Id == userId, update);
    }
}
