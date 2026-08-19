// Program.cs
using backend.Models;
using backend;
using backend.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Options; // Make sure this is included for IOptions
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models; // Added for OpenApiInfo
using MongoDB.Bson.Serialization;
using System.Text;
using System.Text.Json; // Added for JsonNamingPolicy
using System.Text.Json.Serialization; // Added for JsonIgnoreCondition

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<MongoDbSettings>(builder.Configuration.GetSection("MongoDbSettings"));
builder.Services.Configure<JwtSettings>(builder.Configuration.GetSection("JwtSettings"));
builder.Services.Configure<EmailSettings>(builder.Configuration.GetSection("EmailSettings"));
builder.Services.AddSingleton<EmailService>();
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
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.PropertyNameCaseInsensitive = true;
        options.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    });

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Technocare API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        In = ParameterLocation.Header,
        Description = "Please insert JWT with Bearer into field",
        Name = "Authorization",
        Type = SecuritySchemeType.ApiKey
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement {
    {
        new OpenApiSecurityScheme
        {
            Reference = new OpenApiReference
            {
                Type = ReferenceType.SecurityScheme,
                Id = "Bearer"
            }
        },
        new string[] { }
    }
    });
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll",
        builder =>
        {
            builder.AllowAnyOrigin() // Allow requests from any origin
                   .AllowAnyMethod() // Allow all HTTP methods (GET, POST, PUT, DELETE, etc.)
                   .AllowAnyHeader(); // Allow all headers
        });
});

if (!BsonClassMap.IsClassMapRegistered(typeof(ServiceApplication)))
{
    BsonClassMap.RegisterClassMap<ServiceApplication>(cm =>
    {
        cm.AutoMap();
        cm.MapIdProperty(a => a.Id).SetElementName("_id");
        cm.MapProperty(a => a.ApplicantName).SetElementName("applicantName");
        cm.MapProperty(a => a.ApplicantEmail).SetElementName("applicantEmail");
        cm.MapProperty(a => a.ApplicantPhone).SetElementName("applicantPhone");
        cm.MapProperty(a => a.AppliedFor).SetElementName("appliedFor");
        cm.MapProperty(a => a.AppliedSubService).SetElementName("appliedSubService"); // Add this
        cm.MapProperty(a => a.Message).SetElementName("message");
        cm.MapProperty(a => a.ApplicationDate).SetElementName("applicationDate");
        cm.MapProperty(a => a.Status).SetElementName("status");
    });
}
if (!BsonClassMap.IsClassMapRegistered(typeof(EducationApplication)))
{
    BsonClassMap.RegisterClassMap<EducationApplication>(cm =>
    {
        cm.AutoMap();
        cm.MapIdProperty(a => a.Id).SetElementName("_id");
        cm.MapProperty(a => a.ApplicantName).SetElementName("applicantName");
        cm.MapProperty(a => a.ApplicantEmail).SetElementName("applicantEmail");
        cm.MapProperty(a => a.ApplicantPhone).SetElementName("applicantPhone");
        cm.MapProperty(a => a.AppliedFor).SetElementName("appliedFor");
        cm.MapProperty(a => a.Message).SetElementName("message");
        cm.MapProperty(a => a.ApplicationDate).SetElementName("applicationDate");
        cm.MapProperty(a => a.Status).SetElementName("status");
    });
}


var app = builder.Build();
app.Use(async (context, next) =>
{
    Console.WriteLine($"Request: {context.Request.Path}");
    await next();
});
//if (app.Environment.IsDevelopment())
//{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Technocare API V1");
    });
//}
app.UseHttpsRedirection();
app.UseStaticFiles(); // Serve static files from wwwroot
app.UseRouting();
app.UseCors("AllowAll"); // Use the CORS policy defined above
app.UseAuthorization(); // Enable authorization middleware
app.MapControllers();
app.MapFallbackToFile("index.html"); // Serve index.html for unknown routes
app.Run();
