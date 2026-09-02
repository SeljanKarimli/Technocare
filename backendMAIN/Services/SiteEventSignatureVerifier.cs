using System.Security.Cryptography;
using System.Text;
using backend.Models;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace backend.Services;

public sealed class SiteEventSignatureVerifier(
    IOptions<TechnocareSiteOptions> options,
    IMemoryCache replayCache)
{
    private static readonly TimeSpan AllowedClockSkew = TimeSpan.FromMinutes(5);
    private readonly string _secret = options.Value.SharedSecret;

    public bool Verify(string body, string? timestampHeader, string? nonce, string? signature)
    {
        if (string.IsNullOrWhiteSpace(_secret) ||
            !long.TryParse(timestampHeader, out var unixTime) ||
            string.IsNullOrWhiteSpace(nonce) || nonce.Length is < 16 or > 128 ||
            string.IsNullOrWhiteSpace(signature) || signature.Length != 64)
        {
            return false;
        }
        DateTimeOffset timestamp;
        try
        {
            timestamp = DateTimeOffset.FromUnixTimeSeconds(unixTime);
        }
        catch (ArgumentOutOfRangeException)
        {
            return false;
        }
        if ((DateTimeOffset.UtcNow - timestamp).Duration() > AllowedClockSkew)
        {
            return false;
        }

        var payload = $"{timestampHeader}.{nonce}.{body}";
        var expected = HMACSHA256.HashData(Encoding.UTF8.GetBytes(_secret), Encoding.UTF8.GetBytes(payload));
        byte[] supplied;
        try
        {
            supplied = Convert.FromHexString(signature);
        }
        catch (FormatException)
        {
            return false;
        }
        if (!CryptographicOperations.FixedTimeEquals(expected, supplied))
        {
            return false;
        }

        var replayKey = "site-event-nonce:" + nonce;
        if (replayCache.TryGetValue(replayKey, out _))
        {
            return false;
        }
        replayCache.Set(replayKey, true, AllowedClockSkew);
        return true;
    }
}
