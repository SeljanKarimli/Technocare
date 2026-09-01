// Models/User.cs
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;
using System.ComponentModel.DataAnnotations;
using System;
using System.Collections.Generic; // Ensure this is included for List<T> if needed elsewhere in User model

namespace backend.Models
{
    public class User
    {
        // MongoDB's BsonId attribute maps the Id property to the '_id' field in MongoDB
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)] // Allows passing the Id as a string in the API
        public string? Id { get; set; }

        [BsonElement("name")]
        public string Name { get; set; } = null!;

        [BsonElement("email")]
        public string Email { get; set; } = null!;

        [BsonElement("normalizedEmail")]
        [BsonIgnoreIfNull]
        public string? NormalizedEmail { get; set; }

        [BsonElement("passwordHash")] // Storing hashed password
        public string PasswordHash { get; set; } = null!;

        [BsonElement("phone")]
        public string Phone { get; set; } = null!; // Keeping phone from Flutter app

        [BsonElement("emailVerified")]
        public bool EmailVerified { get; set; } = false;

        [BsonElement("verificationToken")]
        public string? VerificationToken { get; set; } // Token for email verification

        [BsonElement("resetToken")]
        public string? ResetToken { get; set; } // Token for password reset

        [BsonElement("resetTokenExpiry")]
        [BsonDateTimeOptions(Kind = DateTimeKind.Utc)] // Store expiry in UTC
        public DateTime? ResetTokenExpiry { get; set; }

        [BsonElement("role")]
        public string Role { get; set; } = "User"; // Default role is "User", can be "Admin"

        // UPDATED: Single Address field (retained from previous iteration)
        [BsonElement("address")]
        public string? Address { get; set; }

        [BsonElement("cartId")]
        [BsonRepresentation(BsonType.ObjectId)]
        public string? CartId { get; set; }
        public string? EmailVerificationCode { get; set; }
        public DateTime? EmailVerificationCodeExpires { get; set; }
    }

    // DTO for user profile update (including single address)
    public class UserProfileUpdateRequest
    {
        public string? Name { get; set; }
        public string? Email { get; set; }
        public string? Phone { get; set; }
        public string? Address { get; set; } // UPDATED: Single Address field
    }
}

// DTO for user registration
public class RegisterRequest
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string Name { get; set; } = null!;

    [Required, EmailAddress, StringLength(254)]
    public string Email { get; set; } = null!;

    [Required, StringLength(64, MinimumLength = 10)]
    public string Password { get; set; } = null!;

    [Required, StringLength(32, MinimumLength = 7)]
    [RegularExpression(@"^(?=(?:\D*\d){7,15}\D*$)[0-9+()\-\s]+$", ErrorMessage = "Telefon nömrəsinin formatı yanlışdır.")]
    public string Phone { get; set; } = null!;
}

// DTO for user login
public class LoginRequest
{
    [Required, EmailAddress, StringLength(254)]
    public string Email { get; set; } = null!;

    [Required, StringLength(64, MinimumLength = 1)]
    public string Password { get; set; } = null!;
}

// DTO for email verification request
public class VerifyEmailRequest
{
    [Required, EmailAddress, StringLength(254)]
    public string Email { get; set; } = null!;

    [Required, StringLength(128, MinimumLength = 6)]
    public string Token { get; set; } = null!;
}

// DTO for
// password request
public class ForgotPasswordRequest
{
    [Required, EmailAddress, StringLength(254)]
    public string Email { get; set; } = null!;
}
// DTO for making admin request
public class MakeAdminRequest
{
    [Required, EmailAddress, StringLength(254)]
    public string Email { get; set; } = null!;
}
// DTO for reset password request
public class ResetPasswordRequest
{
    [Required, EmailAddress, StringLength(254)]
    public string Email { get; set; } = null!;

    [Required, StringLength(128, MinimumLength = 16)]
    public string Token { get; set; } = null!;

    [Required, StringLength(64, MinimumLength = 10)]
    public string NewPassword { get; set; } = null!;
}
public class ResendVerificationRequest
{
    [Required, EmailAddress, StringLength(254)]
    public string Email { get; set; } = null!;
}

// DTO for user response (excluding sensitive info)
public class UserResponse
{
    public string Id { get; set; } = null!;
    public string Name { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string Phone { get; set; } = null!;
    public string Role { get; set; } = null!;
    public bool EmailVerified { get; set; }
    public string? Token { get; set; } // JWT token
    public string? CartId { get; set; }
}
