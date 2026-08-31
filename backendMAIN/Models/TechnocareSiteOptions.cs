namespace backend.Models;

public sealed class TechnocareSiteOptions
{
    public const string SectionName = "TechnocareSite";

    public string BaseUrl { get; set; } = "https://technocare.az";
    public string SharedSecret { get; set; } = string.Empty;
    public int CacheMinutes { get; set; } = 5;
    public int TimeoutSeconds { get; set; } = 15;
}
