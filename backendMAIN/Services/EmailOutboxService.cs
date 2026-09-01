using backend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Driver;

namespace backend.Services;

public sealed class EmailOutboxService : BackgroundService
{
    private readonly IMongoCollection<EmailOutboxMessage> _messages;
    private readonly EmailService _emailService;
    private readonly ILogger<EmailOutboxService> _logger;

    public EmailOutboxService(
        IOptions<MongoDbSettings> settings,
        EmailService emailService,
        ILogger<EmailOutboxService> logger)
    {
        var client = new MongoClient(settings.Value.ConnectionString);
        var database = client.GetDatabase(settings.Value.DatabaseName);
        _messages = database.GetCollection<EmailOutboxMessage>(settings.Value.EmailOutboxCollectionName);
        _emailService = emailService;
        _logger = logger;
    }

    public Task EnqueueAsync(string to, string subject, string htmlBody, CancellationToken cancellationToken = default)
    {
        var message = new EmailOutboxMessage
        {
            To = to.Trim().ToLowerInvariant(),
            Subject = subject,
            HtmlBody = htmlBody,
        };
        return _messages.InsertOneAsync(message, cancellationToken: cancellationToken);
    }

    public Task EnqueueVerificationAsync(string email, string code, CancellationToken cancellationToken = default) =>
        EnqueueAsync(
            email,
            "Technocare email təsdiqi",
            $"<p>Technocare hesabınızı təsdiqləmək üçün kod:</p><p><strong>{code}</strong></p><p>Kod 10 dəqiqə ərzində etibarlıdır.</p>",
            cancellationToken);

    public Task EnqueuePasswordResetAsync(string email, string token, CancellationToken cancellationToken = default) =>
        EnqueueAsync(
            email,
            "Technocare şifrəsinin bərpası",
            $"<p>Şifrənizi yeniləmək üçün aşağıdakı kodu tətbiqdə daxil edin:</p><p><strong>{token}</strong></p><p>Kod 1 saat ərzində etibarlıdır. Bu sorğunu siz etməmisinizsə, məktubu nəzərə almayın.</p>",
            cancellationToken);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await EnsureIndexesAsync(stoppingToken);
        while (!stoppingToken.IsCancellationRequested)
        {
            var now = DateTime.UtcNow;
            var message = await _messages
                .Find(item => item.SentAt == null && item.NextAttemptAt <= now)
                .SortBy(item => item.CreatedAt)
                .FirstOrDefaultAsync(stoppingToken);

            if (message is null)
            {
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                continue;
            }

            try
            {
                await _emailService.SendEmailAsync(message.To, message.Subject, message.HtmlBody);
                await _messages.UpdateOneAsync(
                    item => item.Id == message.Id,
                    Builders<EmailOutboxMessage>.Update
                        .Set(item => item.SentAt, DateTime.UtcNow)
                        .Unset(item => item.LastErrorType),
                    cancellationToken: stoppingToken);
            }
            catch (Exception exception) when (!stoppingToken.IsCancellationRequested)
            {
                var attempts = message.Attempts + 1;
                var delayMinutes = Math.Min(60, Math.Pow(2, Math.Min(attempts, 6)));
                await _messages.UpdateOneAsync(
                    item => item.Id == message.Id,
                    Builders<EmailOutboxMessage>.Update
                        .Set(item => item.Attempts, attempts)
                        .Set(item => item.NextAttemptAt, DateTime.UtcNow.AddMinutes(delayMinutes))
                        .Set(item => item.LastErrorType, exception.GetType().Name),
                    cancellationToken: stoppingToken);
                _logger.LogWarning("Email outbox delivery failed; message will be retried. Attempt {Attempt}.", attempts);
            }
        }
    }

    private async Task EnsureIndexesAsync(CancellationToken cancellationToken)
    {
        var pending = new CreateIndexModel<EmailOutboxMessage>(
            Builders<EmailOutboxMessage>.IndexKeys
                .Ascending(item => item.SentAt)
                .Ascending(item => item.NextAttemptAt),
            new CreateIndexOptions<EmailOutboxMessage> { Name = "ix_email_outbox_pending" });
        var expiry = new CreateIndexModel<EmailOutboxMessage>(
            Builders<EmailOutboxMessage>.IndexKeys.Ascending(item => item.SentAt),
            new CreateIndexOptions<EmailOutboxMessage>
            {
                Name = "ttl_email_outbox_sent",
                ExpireAfter = TimeSpan.FromDays(7),
                PartialFilterExpression = new BsonDocument(
                    "sentAt",
                    new BsonDocument("$type", "date")),
            });
        await _messages.Indexes.CreateManyAsync([pending, expiry], cancellationToken);
    }
}
