using backend.Models;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Options;

namespace backend.Services;

public sealed class FirebasePushService
{
    private readonly FirebaseSettings _settings;
    private readonly Lazy<FirebaseMessaging?> _messaging;

    public FirebasePushService(IOptions<FirebaseSettings> settings, ILogger<FirebasePushService> logger)
    {
        _settings = settings.Value;
        _messaging = new Lazy<FirebaseMessaging?>(() => CreateMessaging(logger));
    }

    public bool IsEnabled => _settings.Enabled;

    public async Task SendAsync(backend.Models.Notification notification, CancellationToken cancellationToken)
    {
        var messaging = _messaging.Value ?? throw new InvalidOperationException("Firebase push is not configured.");
        await messaging.SendAsync(new Message
        {
            Topic = string.IsNullOrWhiteSpace(_settings.Topic) ? "technocare-site-updates" : _settings.Topic.Trim(),
            Notification = new FirebaseAdmin.Messaging.Notification
            {
                Title = notification.Title,
                Body = notification.Message,
            },
            Data = new Dictionary<string, string>
            {
                ["notificationId"] = notification.Id ?? string.Empty,
                ["category"] = notification.Category ?? "website",
                ["url"] = notification.Url ?? string.Empty,
            },
            Android = new AndroidConfig
            {
                Priority = Priority.High,
                Notification = new AndroidNotification { ChannelId = "technocare_updates" },
            },
            Apns = new ApnsConfig { Aps = new Aps { Sound = "default" } },
        }, dryRun: false, cancellationToken);
    }

    private FirebaseMessaging? CreateMessaging(ILogger logger)
    {
        if (!_settings.Enabled)
        {
            logger.LogInformation("Firebase push is disabled; website updates remain available in the in-app feed.");
            return null;
        }
        if (string.IsNullOrWhiteSpace(_settings.ProjectId))
        {
            throw new InvalidOperationException("Firebase:ProjectId is required when Firebase is enabled.");
        }
        GoogleCredential credential = string.IsNullOrWhiteSpace(_settings.ServiceAccountJson)
            ? GoogleCredential.GetApplicationDefault()
            : CredentialFactory.FromJson<ServiceAccountCredential>(_settings.ServiceAccountJson).ToGoogleCredential();
        const string appName = "technocare-backend";
        var app = FirebaseApp.Create(new AppOptions
        {
            Credential = credential,
            ProjectId = _settings.ProjectId,
        }, appName);
        return FirebaseMessaging.GetMessaging(app);
    }
}

public sealed class PushNotificationWorker(
    NotificationService notifications,
    FirebasePushService push,
    ILogger<PushNotificationWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await notifications.EnsureIndexesAsync(stoppingToken);
        while (!stoppingToken.IsCancellationRequested)
        {
            if (!push.IsEnabled)
            {
                await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
                continue;
            }
            var item = await notifications.GetPendingPushAsync(stoppingToken);
            if (item?.Id is null)
            {
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                continue;
            }
            try
            {
                await push.SendAsync(item, stoppingToken);
                await notifications.MarkPushSentAsync(item.Id, stoppingToken);
            }
            catch (Exception exception) when (!stoppingToken.IsCancellationRequested)
            {
                await notifications.MarkPushFailedAsync(item, exception, stoppingToken);
                logger.LogWarning("Firebase push delivery failed for notification {NotificationId}; it will be retried.", item.Id);
            }
        }
    }
}
