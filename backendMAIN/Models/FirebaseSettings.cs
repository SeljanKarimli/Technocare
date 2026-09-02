namespace backend.Models;

public sealed class FirebaseSettings
{
    public const string SectionName = "Firebase";

    public bool Enabled { get; set; }
    public string ProjectId { get; set; } = string.Empty;
    public string Topic { get; set; } = "technocare-site-updates";
    public string ServiceAccountJson { get; set; } = string.Empty;
}
