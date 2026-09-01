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
            return await _siteClient.CheckHealthAsync(cancellationToken)
                ? HealthCheckResult.Healthy("technocare.az API is reachable.")
                : HealthCheckResult.Unhealthy("technocare.az API returned an unsuccessful status.");
        }
        catch (Exception exception)
        {
            return HealthCheckResult.Unhealthy("technocare.az API is unavailable; stale content may be served.", exception);
        }
    }
}
