using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace backend.Services;

public sealed class TechnocareSiteHealthCheck : IHealthCheck
{
    private readonly ITechnocareSiteClient _siteClient;

    public TechnocareSiteHealthCheck(ITechnocareSiteClient siteClient)
    {
        _siteClient = siteClient;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            await _siteClient.GetCategoriesAsync(cancellationToken);
            return HealthCheckResult.Healthy("technocare.az API is reachable.");
        }
        catch (Exception exception)
        {
            return HealthCheckResult.Degraded("technocare.az API is unavailable; stale content may be served.", exception);
        }
    }
}
