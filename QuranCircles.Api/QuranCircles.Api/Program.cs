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

// 2. Database Context with WAL mode & multi-provider readiness
var dbPath = Path.Combine(AppContext.BaseDirectory, "quran.db");
builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlite(builder.Configuration.GetConnectionString("Default") ?? $"Data Source={dbPath};Cache=Shared;"));

// 3. Enterprise Services & In-Memory Caching
builder.Services.AddMemoryCache();
builder.Services.AddScoped<QuranCircles.Api.Services.StudentService>();
builder.Services.AddScoped<QuranCircles.Api.Services.TeacherService>();
builder.Services.AddScoped<QuranCircles.Api.Services.CircleService>();
builder.Services.AddScoped<QuranCircles.Api.Services.SessionService>();
builder.Services.AddScoped<QuranCircles.Api.Services.AttendanceService>();
builder.Services.AddScoped<QuranCircles.Api.Services.ReportService>();
builder.Services.AddScoped<QuranCircles.Api.Services.AnnouncementService>();
builder.Services.AddSingleton<QuranCircles.Api.Services.PasswordHasher>();
builder.Services.AddSingleton<QuranCircles.Api.Services.TokenService>();

// 4. Configurable Enterprise CORS Policy
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? new[]
{
    "http://localhost:5070",
    "http://127.0.0.1:5070",
    "https://khaledhaniya.github.io",
    "https://albayan-quran.onrender.com"
};

builder.Services.AddCors(options =>
{
    options.AddPolicy("EnterpriseCors", policy =>
    {
        policy.SetIsOriginAllowed(origin =>
              {
                  if (string.IsNullOrEmpty(origin)) return false;
                  var uri = new Uri(origin);
                  return uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
                         uri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase) ||
                         allowedOrigins.Contains(origin, StringComparer.OrdinalIgnoreCase) ||
                         origin.EndsWith(".github.io", StringComparison.OrdinalIgnoreCase) ||
                         origin.EndsWith(".onrender.com", StringComparison.OrdinalIgnoreCase);
              })
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
    // Fallback permissive policy for simple clients
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

app.UseCors("EnterpriseCors");
app.UseResponseCompression();

// Database Initialization with WAL Mode Concurrency Tuning
using (var scope = app.Services.CreateScope())
{
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var hasher = scope.ServiceProvider.GetRequiredService<QuranCircles.Api.Services.PasswordHasher>();
        db.Database.EnsureCreated();
        
        // Enable SQLite WAL mode (Write-Ahead Logging) and busy timeout to eliminate locks
        try
        {
            db.Database.ExecuteSqlRaw("PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000; PRAGMA synchronous=NORMAL;");
        }
        catch { /* Handled for other database engines */ }

        DbSeeder.MigrateSchema(db);
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

// 5. Root & Health Check Endpoints
app.MapGet("/", () => Results.Ok(new
{
    status = "online",
    center = "مركز البيان لتعليم القرآن الكريم وتدريس علومه",
    timestamp = DateTime.UtcNow,
    version = "1.1.0",
    engine = "ASP.NET Core 9.0 Enterprise Edition"
}));

app.MapGet("/healthz", async (AppDbContext db) =>
{
    try
    {
        var canConnect = await db.Database.CanConnectAsync();
        return canConnect 
            ? Results.Ok(new { status = "healthy", database = "connected", timestamp = DateTime.UtcNow })
            : Results.Json(new { status = "degraded", database = "unreachable" }, statusCode: 503);
    }
    catch (Exception ex)
    {
        return Results.Json(new { status = "unhealthy", error = ex.Message }, statusCode: 500);
    }
});

app.MapControllers();

app.Run();