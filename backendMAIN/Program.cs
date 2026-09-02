using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using backend;
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using MongoDB.Bson.Serialization;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOptions<MongoDbSettings>()
    .Bind(builder.Configuration.GetSection("MongoDbSettings"))
    .Validate(settings => !string.IsNullOrWhiteSpace(settings.ConnectionString), "MongoDB connection string is required.")
    .ValidateOnStart();
builder.Services.AddOptions<JwtSettings>()
    .Bind(builder.Configuration.GetSection("JwtSettings"))
    .Validate(settings => !string.IsNullOrWhiteSpace(settings.Secret) && settings.Secret.Length >= 32, "JWT secret must be at least 32 characters.")
    .ValidateOnStart();
builder.Services.Configure<EmailSettings>(builder.Configuration.GetSection("EmailSettings"));
builder.Services.Configure<AdminBootstrapOptions>(builder.Configuration.GetSection(AdminBootstrapOptions.SectionName));
builder.Services.AddOptions<TechnocareSiteOptions>()
    .Bind(builder.Configuration.GetSection(TechnocareSiteOptions.SectionName))
    .Validate(settings => Uri.TryCreate(settings.BaseUrl, UriKind.Absolute, out var uri) && uri.Scheme == Uri.UriSchemeHttps, "TechnocareSite:BaseUrl must be HTTPS.")
    .ValidateOnStart();

builder.Services.AddSingleton<EmailService>();
builder.Services.AddSingleton<EmailOutboxService>();
builder.Services.AddHostedService<EmailOutboxService>(serviceProvider => serviceProvider.GetRequiredService<EmailOutboxService>());
builder.Services.AddSingleton<UserService>();
builder.Services.AddSingleton<ServiceApplicationService>();
builder.Services.AddSingleton<ProductService>();
builder.Services.AddSingleton<ProjectService>();
builder.Services.AddSingleton<CartService>();
builder.Services.AddSingleton<EducationApplicationService>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddSingleton<OrderService>();
builder.Services.AddSingleton<CategoryService>();
builder.Services.AddSingleton<NotificationService>();
builder.Services.AddSingleton<MongoDbContext>();
builder.Services.AddScoped<ShopCartService>();
builder.Services.AddHostedService<ShopCartIndexInitializer>();
builder.Services.AddHostedService<UserIndexInitializer>();
builder.Services.AddHostedService<AdminRoleBootstrapper>();

builder.Services.AddMemoryCache();
builder.Services.AddHttpClient("TechnocareMedia", client =>
{
    client.Timeout = TimeSpan.FromSeconds(30);
    client.DefaultRequestHeaders.UserAgent.ParseAdd("TechnocareAppMedia/1.0");
}).ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
{
    AllowAutoRedirect = false,
    AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate | DecompressionMethods.Brotli,
    PooledConnectionLifetime = TimeSpan.FromMinutes(10),
});
builder.Services.AddHttpClient<ITechnocareSiteClient, TechnocareSiteClient>((serviceProvider, client) =>
{
    var settings = serviceProvider.GetRequiredService<Microsoft.Extensions.Options.IOptions<TechnocareSiteOptions>>().Value;
    client.BaseAddress = new Uri(settings.BaseUrl.TrimEnd('/') + "/");
    client.Timeout = TimeSpan.FromSeconds(Math.Clamp(settings.TimeoutSeconds, 5, 60));
    client.DefaultRequestHeaders.UserAgent.ParseAdd("TechnocareAppBackend/1.0");
}).ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
{
    AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate | DecompressionMethods.Brotli,
    PooledConnectionLifetime = TimeSpan.FromMinutes(10),
});

var jwt = builder.Configuration.GetSection("JwtSettings").Get<JwtSettings>()
    ?? throw new InvalidOperationException("JwtSettings are missing.");
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
        options.SaveToken = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Secret)),
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddControllers().AddJsonOptions(options =>
{
    options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    options.JsonSerializerOptions.PropertyNameCaseInsensitive = true;
    options.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
});
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<ApiExceptionHandler>();
builder.Services.AddResponseCaching(options =>
{
    options.MaximumBodySize = 16 * 1024 * 1024;
});
builder.Services.AddHealthChecks()
    .AddCheck<TechnocareSiteHealthCheck>("technocare-site", tags: ["ready"])
    .AddCheck<MongoDbHealthCheck>("mongodb", tags: ["ready"]);
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 120,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true,
            }));
    options.AddPolicy("auth", httpContext => RateLimitPartition.GetFixedWindowLimiter(
        "auth:" + (httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown"),
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 10,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0,
            AutoReplenishment = true,
        }));
    options.AddPolicy("applications", httpContext => RateLimitPartition.GetFixedWindowLimiter(
        "applications:" + (httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown"),
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 5,
            Window = TimeSpan.FromHours(1),
            QueueLimit = 0,
            AutoReplenishment = true,
        }));
    options.AddPolicy("search", httpContext => RateLimitPartition.GetFixedWindowLimiter(
        "search:" + (httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown"),
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 60,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0,
            AutoReplenishment = true,
        }));
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "Technocare API", Version = "v1" });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        In = ParameterLocation.Header,
        Description = "JWT bearer token",
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        [new OpenApiSecurityScheme
        {
            Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" },
        }] = Array.Empty<string>(),
    });
});

var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
    ?? ["https://technocare.az", "https://www.technocare.az"];
builder.Services.AddCors(options => options.AddPolicy("Technocare", policy =>
    policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod()));

RegisterMongoMaps();

var app = builder.Build();
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
});
app.UseExceptionHandler();
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}
else
{
    app.UseSwagger();
    app.UseSwaggerUI(options => options.SwaggerEndpoint("/swagger/v1/swagger.json", "Technocare API V1"));
}
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();
app.UseCors("Technocare");
app.UseResponseCaching();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false,
});
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = registration => registration.Tags.Contains("ready"),
    ResultStatusCodes =
    {
        [Microsoft.Extensions.Diagnostics.HealthChecks.HealthStatus.Degraded] = StatusCodes.Status503ServiceUnavailable,
        [Microsoft.Extensions.Diagnostics.HealthChecks.HealthStatus.Unhealthy] = StatusCodes.Status503ServiceUnavailable,
    },
});
app.MapHealthChecks("/health", new HealthCheckOptions
{
    Predicate = registration => registration.Tags.Contains("ready"),
    ResultStatusCodes =
    {
        [Microsoft.Extensions.Diagnostics.HealthChecks.HealthStatus.Degraded] = StatusCodes.Status503ServiceUnavailable,
        [Microsoft.Extensions.Diagnostics.HealthChecks.HealthStatus.Unhealthy] = StatusCodes.Status503ServiceUnavailable,
    },
});
app.MapFallbackToFile("index.html");
app.Run();

static void RegisterMongoMaps()
{
    if (!BsonClassMap.IsClassMapRegistered(typeof(ServiceApplication)))
    {
        BsonClassMap.RegisterClassMap<ServiceApplication>(map =>
        {
            map.AutoMap();
            map.MapIdProperty(item => item.Id).SetElementName("_id");
        });
    }

    if (!BsonClassMap.IsClassMapRegistered(typeof(EducationApplication)))
    {
        BsonClassMap.RegisterClassMap<EducationApplication>(map =>
        {
            map.AutoMap();
            map.MapIdProperty(item => item.Id).SetElementName("_id");
        });
    }
}

public partial class Program;
