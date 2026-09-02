using System.Net;
using backend.Models;

namespace backend.Services;

public static class ApplicationEmailComposer
{
    public static (string Subject, string HtmlBody) Service(ServiceApplication application) =>
        Compose(
            "Yeni xidmət müraciəti",
            application.ApplicantName,
            application.ApplicantEmail,
            application.ApplicantPhone,
            application.AppliedFor,
            application.AppliedSubService,
            application.Message,
            application.ApplicationDate);

    public static (string Subject, string HtmlBody) Education(EducationApplication application) =>
        Compose(
            "Yeni təhsil müraciəti",
            application.ApplicantName,
            application.ApplicantEmail,
            application.ApplicantPhone,
            application.AppliedFor,
            null,
            application.Message,
            application.ApplicationDate);

    private static (string Subject, string HtmlBody) Compose(
        string heading,
        string name,
        string email,
        string phone,
        string appliedFor,
        string? subService,
        string? message,
        DateTime submittedAt)
    {
        static string Encode(string? value) => WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(value) ? "—" : value.Trim());

        var subject = $"{heading} — {appliedFor.Trim()}";
        var rows = new List<string>
        {
            $"<tr><th align=\"left\">Ad və soyad</th><td>{Encode(name)}</td></tr>",
            $"<tr><th align=\"left\">E-poçt</th><td>{Encode(email)}</td></tr>",
            $"<tr><th align=\"left\">Telefon</th><td>{Encode(phone)}</td></tr>",
            $"<tr><th align=\"left\">Müraciət sahəsi</th><td>{Encode(appliedFor)}</td></tr>",
        };
        if (!string.IsNullOrWhiteSpace(subService))
        {
            rows.Add($"<tr><th align=\"left\">Alt xidmət</th><td>{Encode(subService)}</td></tr>");
        }
        rows.Add($"<tr><th align=\"left\">Mesaj</th><td>{Encode(message)}</td></tr>");
        rows.Add($"<tr><th align=\"left\">Göndərilmə vaxtı</th><td>{submittedAt:yyyy-MM-dd HH:mm} UTC</td></tr>");

        var body = $"<h2>{Encode(heading)}</h2><table cellpadding=\"8\" cellspacing=\"0\" border=\"1\" style=\"border-collapse:collapse\">{string.Join(string.Empty, rows)}</table>";
        return (subject, body);
    }
}
