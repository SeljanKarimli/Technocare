namespace backend.Services;

public static class MediaProxySource
{
    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".avif",
        ".gif",
        ".jpeg",
        ".jpg",
        ".png",
        ".webp",
    };

    public static bool TryNormalize(string? value, out Uri source)
    {
        source = null!;
        if (!Uri.TryCreate(value?.Trim(), UriKind.Absolute, out var candidate) ||
            candidate.Scheme != Uri.UriSchemeHttps ||
            !candidate.Host.Equals("technocare.az", StringComparison.OrdinalIgnoreCase) ||
            !candidate.IsDefaultPort && candidate.Port != 443 ||
            !string.IsNullOrEmpty(candidate.UserInfo) ||
            !candidate.AbsolutePath.StartsWith("/wp-content/uploads/", StringComparison.Ordinal) ||
            !AllowedExtensions.Contains(Path.GetExtension(candidate.AbsolutePath)))
        {
            return false;
        }

        source = new UriBuilder(candidate) { Fragment = string.Empty }.Uri;
        return true;
    }
}
