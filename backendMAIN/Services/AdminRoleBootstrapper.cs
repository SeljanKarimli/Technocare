using Microsoft.Extensions.Options;

namespace backend.Services;

public sealed class AdminBootstrapOptions
{
    public const string SectionName = "AdminBootstrap";
    public string Email { get; set; } = string.Empty;
}

public sealed class AdminRoleBootstrapper : IHostedService
{
    private readonly UserService _users;
    private readonly AdminBootstrapOptions _options;
    private readonly ILogger<AdminRoleBootstrapper> _logger;

    public AdminRoleBootstrapper(
        UserService users,
        IOptions<AdminBootstrapOptions> options,
        ILogger<AdminRoleBootstrapper> logger)
    {
        _users = users;
        _options = options.Value;
        _logger = logger;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.Email))
        {
            return;
        }

        var user = await _users.GetByEmailAsync(_options.Email);
        if (user is null || !user.EmailVerified)
        {
            _logger.LogWarning("Configured admin bootstrap account was not found or is not verified.");
            return;
        }
        if (!string.Equals(user.Role, "Admin", StringComparison.Ordinal))
        {
            await _users.UpdateUserRoleAsync(user.Id!, "Admin");
            _logger.LogInformation("Verified admin role bootstrap completed.");
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
