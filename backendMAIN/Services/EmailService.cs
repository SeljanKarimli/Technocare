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

    public EmailService(IOptions<EmailSettings> emailSettings)
    {
        _emailSettings = emailSettings.Value;

        // Debugging output
        Console.WriteLine("--- EmailSettings Debug (Constructor) ---");
        Console.WriteLine($"SmtpServer: {_emailSettings.SmtpServer ?? "NULL"}");
        Console.WriteLine($"SmtpPort: {_emailSettings.SmtpPort}");
        Console.WriteLine($"SmtpUser: {_emailSettings.SmtpUser ?? "NULL"}");
        Console.WriteLine($"SmtpPass: {(!string.IsNullOrEmpty(_emailSettings.SmtpPass) ? "******" : "NULL/Empty")}");
        Console.WriteLine($"SenderName: {_emailSettings.SenderName ?? "NULL"}");
        Console.WriteLine($"SenderEmail: {_emailSettings.SenderEmail ?? "NULL"}");
        Console.WriteLine("-----------------------------------------");
    }

    public async Task SendEmailAsync(string toEmail, string subject, string htmlMessage)
    {
        if (string.IsNullOrEmpty(toEmail))
        {
            throw new ArgumentException("Recipient email cannot be null or empty", nameof(toEmail));
        }

        var email = new MimeMessage();

        Console.WriteLine("--- MailboxAddress Creation Debug ---");
        Console.WriteLine($"Creating sender address with Name: {_emailSettings.SenderName}, Email: {_emailSettings.SenderEmail}");
        Console.WriteLine($"Creating recipient address with Email: {toEmail}");
        Console.WriteLine("-----------------------------------");

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
            Console.WriteLine($"Error sending email: {ex.Message}");
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