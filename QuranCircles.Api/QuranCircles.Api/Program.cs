using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;

Environment.SetEnvironmentVariable("DOTNET_USE_POLLING_FILE_WATCHER", "true");

var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = AppContext.BaseDirectory
});

builder.Host.ConfigureAppConfiguration((hostingContext, config) =>
{
    config.Sources.Clear();
    config.AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
          .AddJsonFile($"appsettings.{hostingContext.HostingEnvironment.EnvironmentName}.json", optional: true, reloadOnChange: false)
          .AddEnvironmentVariables();
});

// 1. Dynamic Port binding for Cloud Providers (Render, Railway, Docker, Localhost)
var port = Environment.GetEnvironmentVariable("PORT") ?? "5070";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

// 2. Database Context with reliable file path resolution
var dbPath = Path.Combine(AppContext.BaseDirectory, "quran.db");
builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlite(builder.Configuration.GetConnectionString("Default") ?? $"Data Source={dbPath};Cache=Shared;"));

builder.Services.AddScoped<QuranCircles.Api.Services.StudentService>();
builder.Services.AddScoped<QuranCircles.Api.Services.TeacherService>();
builder.Services.AddScoped<QuranCircles.Api.Services.CircleService>();
builder.Services.AddScoped<QuranCircles.Api.Services.SessionService>();
builder.Services.AddScoped<QuranCircles.Api.Services.AttendanceService>();
builder.Services.AddScoped<QuranCircles.Api.Services.ReportService>();
builder.Services.AddScoped<QuranCircles.Api.Services.AnnouncementService>();
builder.Services.AddSingleton<QuranCircles.Api.Services.PasswordHasher>();
builder.Services.AddSingleton<QuranCircles.Api.Services.TokenService>();

// 3. CORS Policy allowing all origins, methods, and headers
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

builder.Services.AddControllers()
    .AddJsonOptions(opt =>
        opt.JsonSerializerOptions.Converters.Add(
            new System.Text.Json.Serialization.JsonStringEnumConverter()));

builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
});

var app = builder.Build();

app.UseCors("AllowAll");
app.UseResponseCompression();

using (var scope = app.Services.CreateScope())
{
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var hasher = scope.ServiceProvider.GetRequiredService<QuranCircles.Api.Services.PasswordHasher>();
        db.Database.EnsureCreated();
        DbSeeder.Seed(db, hasher);
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Database initialization notice: {ex.Message}");
    }
}

// Enterprise Security Headers
app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "SAMEORIGIN";
    context.Response.Headers["X-XSS-Protection"] = "1; mode=block";
    context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    await next();
});

// 4. Root & Health Check Endpoints
app.MapGet("/", () => Results.Ok(new
{
    status = "online",
    center = "مركز البيان لتعليم القرآن الكريم وتدريس علومه",
    timestamp = DateTime.UtcNow,
    version = "1.0.0"
}));

app.MapGet("/healthz", () => Results.Ok("OK"));

app.MapControllers();

app.Run();