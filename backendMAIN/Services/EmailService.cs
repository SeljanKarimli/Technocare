using MailKit.Net.Smtp;
using Microsoft.Extensions.Options;
using MimeKit;
using System.Threading.Tasks;
using backend.Models;
using System;

namespace backend.Services;

public class EmailService
{
    private readonly EmailSettings _emailSettings;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IOptions<EmailSettings> emailSettings, ILogger<EmailService> logger)
    {
        _emailSettings = emailSettings.Value;
        _logger = logger;
    }

    public async Task SendEmailAsync(string toEmail, string subject, string htmlMessage)
    {
        if (string.IsNullOrEmpty(toEmail))
        {
            throw new ArgumentException("Recipient email cannot be null or empty", nameof(toEmail));
        }

        var email = new MimeMessage();

        email.From.Add(new MailboxAddress(_emailSettings.SenderName, _emailSettings.SenderEmail));
        email.To.Add(new MailboxAddress("", toEmail));
        email.Subject = subject;

        var bodyBuilder = new BodyBuilder { HtmlBody = htmlMessage };
        email.Body = bodyBuilder.ToMessageBody();

        using var client = new SmtpClient();
        try
        {
            await client.ConnectAsync(_emailSettings.SmtpServer, _emailSettings.SmtpPort, MailKit.Security.SecureSocketOptions.StartTls);
            await client.AuthenticateAsync(_emailSettings.SmtpUser, _emailSettings.SmtpPass);
            await client.SendAsync(email);
            await client.DisconnectAsync(true);
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Email delivery failed: {ExceptionType}", ex.GetType().Name);
            throw;
        }
    }

    public async Task SendVerificationCodeEmail(string email, string code)
    {
        var subject = "Technocare Email Verification";
        var body = $"Your verification code is: {code}";
        await SendEmailAsync(email, subject, body);
    }
}
