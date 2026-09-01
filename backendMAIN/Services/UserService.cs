using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Driver;

namespace backend.Services;

public sealed class UserService
{
    private const string TokenHashPrefix = "sha256:";
    private readonly IMongoCollection<User> _users;
    private readonly IMongoCollection<Cart> _legacyCarts;
    private readonly IMongoCollection<ShopCart> _shopCarts;
    private readonly EmailOutboxService _emailOutbox;
    private readonly TokenService _tokenService;
    private readonly ILogger<UserService> _logger;

    public UserService(
        IOptions<MongoDbSettings> settings,
        EmailOutboxService emailOutbox,
        TokenService tokenService,
        ILogger<UserService> logger)
    {
        var client = new MongoClient(settings.Value.ConnectionString);
        var database = client.GetDatabase(settings.Value.DatabaseName);
        _users = database.GetCollection<User>(settings.Value.UsersCollectionName);
        _legacyCarts = database.GetCollection<Cart>(settings.Value.CartsCollectionName);
        _shopCarts = database.GetCollection<ShopCart>(settings.Value.ShopCartsCollectionName);
        _emailOutbox = emailOutbox;
        _tokenService = tokenService;
        _logger = logger;
    }

    public static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();

    public string HashPassword(string password) => BCrypt.Net.BCrypt.HashPassword(password, workFactor: 12);

    public bool VerifyPassword(string inputPassword, string storedHash)
    {
        try
        {
            return BCrypt.Net.BCrypt.Verify(inputPassword, storedHash);
        }
        catch (BCrypt.Net.SaltParseException)
        {
            return false;
        }
    }

    public Task<List<User>> GetAllAsync() => _users.Find(_ => true).ToListAsync();

    public async Task<bool> DeleteAsync(string userId)
    {
        var user = await GetByIdAsync(userId);
        if (user is null)
        {
            return false;
        }

        await _shopCarts.DeleteManyAsync(cart => cart.UserId == userId);
        if (!string.IsNullOrWhiteSpace(user.CartId))
        {
            await _legacyCarts.DeleteOneAsync(cart => cart.Id == user.CartId);
        }
        return (await _users.DeleteOneAsync(item => item.Id == userId)).DeletedCount == 1;
    }

    public string GenerateJwtToken(User user) => _tokenService.GenerateJwtToken(user);

    public async Task<User?> GetByEmailAsync(string email)
    {
        var normalized = NormalizeEmail(email);
        var filter = Builders<User>.Filter.Or(
            Builders<User>.Filter.Eq(user => user.NormalizedEmail, normalized),
            Builders<User>.Filter.Regex(user => user.Email, new BsonRegularExpression($"^{Regex.Escape(normalized)}$", "i")));
        var user = await _users.Find(filter).FirstOrDefaultAsync();
        if (user is not null && user.NormalizedEmail != normalized)
        {
            try
            {
                await _users.UpdateOneAsync(
                    item => item.Id == user.Id,
                    Builders<User>.Update
                        .Set(item => item.Email, normalized)
                        .Set(item => item.NormalizedEmail, normalized));
                user.Email = normalized;
                user.NormalizedEmail = normalized;
            }
            catch (MongoWriteException exception) when (exception.WriteError?.Category == ServerErrorCategory.DuplicateKey)
            {
                _logger.LogWarning("A duplicate normalized email was detected while migrating a legacy user.");
            }
        }
        return user;
    }

    public async Task<bool> UpdateUserRoleAsync(string id, string newRole)
    {
        var update = Builders<User>.Update.Set(user => user.Role, newRole);
        return (await _users.UpdateOneAsync(user => user.Id == id, update)).ModifiedCount > 0;
    }

    public async Task<UserResponse?> RegisterAsync(RegisterRequest request)
    {
        var normalizedEmail = NormalizeEmail(request.Email);
        if (await GetByEmailAsync(normalizedEmail) is not null)
        {
            return null;
        }

        var code = RandomNumberGenerator.GetInt32(100000, 1000000).ToString();
        var user = new User
        {
            Name = request.Name.Trim(),
            Email = normalizedEmail,
            NormalizedEmail = normalizedEmail,
            PasswordHash = HashPassword(request.Password),
            Phone = request.Phone.Trim(),
            EmailVerified = false,
            EmailVerificationCode = HashOneTimeToken(code),
            EmailVerificationCodeExpires = DateTime.UtcNow.AddMinutes(10),
            Role = "User",
        };

        try
        {
            await _users.InsertOneAsync(user);
        }
        catch (MongoWriteException exception) when (exception.WriteError?.Category == ServerErrorCategory.DuplicateKey)
        {
            return null;
        }

        try
        {
            await _emailOutbox.EnqueueVerificationAsync(user.Email, code);
        }
        catch (Exception exception)
        {
            _logger.LogWarning("Verification email could not be queued after registration: {ExceptionType}", exception.GetType().Name);
        }

        return ToResponse(user);
    }

    public async Task<bool> VerifyEmailAsync(string email, string code)
    {
        var user = await GetByEmailAsync(email);
        if (user is null || user.EmailVerified || user.EmailVerificationCodeExpires <= DateTime.UtcNow ||
            !OneTimeTokenMatches(code.Trim(), user.EmailVerificationCode))
        {
            return false;
        }

        var update = Builders<User>.Update
            .Set(item => item.EmailVerified, true)
            .Unset(item => item.EmailVerificationCode)
            .Unset(item => item.EmailVerificationCodeExpires);
        return (await _users.UpdateOneAsync(item => item.Id == user.Id, update)).ModifiedCount > 0;
    }

    public async Task<UserResponse?> LoginAsync(LoginRequest request)
    {
        var user = await GetByEmailAsync(request.Email);
        if (user is null || !VerifyPassword(request.Password, user.PasswordHash))
        {
            return null;
        }

        var response = ToResponse(user);
        if (user.EmailVerified)
        {
            response.Token = _tokenService.GenerateJwtToken(user);
        }
        return response;
    }

    public async Task<bool> SendPasswordResetEmailAsync(string email)
    {
        var user = await GetByEmailAsync(email);
        if (user is null)
        {
            return true;
        }

        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(24)).ToLowerInvariant();
        await _users.UpdateOneAsync(
            item => item.Id == user.Id,
            Builders<User>.Update
                .Set(item => item.ResetToken, HashOneTimeToken(token))
                .Set(item => item.ResetTokenExpiry, DateTime.UtcNow.AddHours(1)));
        await _emailOutbox.EnqueuePasswordResetAsync(user.Email, token);
        return true;
    }

    public async Task<bool> ResendVerificationEmailAsync(string email)
    {
        var user = await GetByEmailAsync(email);
        if (user is null || user.EmailVerified)
        {
            return true;
        }

        var code = RandomNumberGenerator.GetInt32(100000, 1000000).ToString();
        await _users.UpdateOneAsync(
            item => item.Id == user.Id,
            Builders<User>.Update
                .Set(item => item.EmailVerificationCode, HashOneTimeToken(code))
                .Set(item => item.EmailVerificationCodeExpires, DateTime.UtcNow.AddMinutes(10)));
        await _emailOutbox.EnqueueVerificationAsync(user.Email, code);
        return true;
    }

    public async Task<bool> ResetPasswordAsync(ResetPasswordRequest request)
    {
        var user = await GetByEmailAsync(request.Email);
        if (user is null || user.ResetTokenExpiry <= DateTime.UtcNow || !OneTimeTokenMatches(request.Token.Trim(), user.ResetToken))
        {
            return false;
        }

        var update = Builders<User>.Update
            .Set(item => item.PasswordHash, HashPassword(request.NewPassword))
            .Unset(item => item.ResetToken)
            .Unset(item => item.ResetTokenExpiry);
        return (await _users.UpdateOneAsync(item => item.Id == user.Id, update)).ModifiedCount > 0;
    }

    public Task<User?> GetByIdAsync(string id) => _users.Find(user => user.Id == id).FirstOrDefaultAsync();

    public Task<List<User>> GetAllUsersAsync() => GetAllAsync();

    public async Task<bool> DeleteUserAsync(string id) =>
        (await _users.DeleteOneAsync(user => user.Id == id)).DeletedCount > 0;

    public async Task RegisterUserAsync(User user)
    {
        var code = RandomNumberGenerator.GetInt32(100000, 1000000).ToString();
        user.Email = NormalizeEmail(user.Email);
        user.NormalizedEmail = user.Email;
        user.EmailVerificationCode = HashOneTimeToken(code);
        user.EmailVerificationCodeExpires = DateTime.UtcNow.AddMinutes(10);
        user.EmailVerified = false;
        await _users.InsertOneAsync(user);
        await _emailOutbox.EnqueueVerificationAsync(user.Email, code);
    }

    public async Task UpdateAsync(User user)
    {
        user.Email = NormalizeEmail(user.Email);
        user.NormalizedEmail = user.Email;
        await _users.ReplaceOneAsync(item => item.Id == user.Id, user);
    }

    public async Task UpdateVerificationAsync(string userId, bool emailVerified, string? code, DateTime? expires)
    {
        var storedCode = string.IsNullOrWhiteSpace(code) ? null : HashOneTimeToken(code);
        var update = Builders<User>.Update
            .Set(user => user.EmailVerified, emailVerified)
            .Set(user => user.EmailVerificationCode, storedCode)
            .Set(user => user.EmailVerificationCodeExpires, expires);
        await _users.UpdateOneAsync(user => user.Id == userId, update);
    }

    private static UserResponse ToResponse(User user) => new()
    {
        Id = user.Id!,
        Name = user.Name,
        Email = user.Email,
        Phone = user.Phone,
        Role = user.Role,
        EmailVerified = user.EmailVerified,
        CartId = user.CartId,
    };

    private static string HashOneTimeToken(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return TokenHashPrefix + Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static bool OneTimeTokenMatches(string presented, string? stored)
    {
        if (string.IsNullOrWhiteSpace(stored))
        {
            return false;
        }
        if (!stored.StartsWith(TokenHashPrefix, StringComparison.Ordinal))
        {
            return string.Equals(presented, stored, StringComparison.Ordinal);
        }
        var expected = HashOneTimeToken(presented);
        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expected),
            Encoding.UTF8.GetBytes(stored));
    }
}
