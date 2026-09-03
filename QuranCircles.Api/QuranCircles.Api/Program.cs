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

// 2. Database Context with Dual Provider (Cloud PostgreSQL / Local SQLite)
var postgresUrl = Environment.GetEnvironmentVariable("DATABASE_URL")
               ?? Environment.GetEnvironmentVariable("POSTGRES_URL")
               ?? Environment.GetEnvironmentVariable("POSTGRESQL_URL")
               ?? builder.Configuration.GetConnectionString("PostgreSql");

string? postgresConnStr = null;
if (!string.IsNullOrWhiteSpace(postgresUrl))
{
    if (postgresUrl.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase) ||
        postgresUrl.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
    {
        try
        {
            var uri = new Uri(postgresUrl);
            var userInfo = uri.UserInfo.Split(':');
            var user = userInfo[0];
            var password = userInfo.Length > 1 ? userInfo[1] : "";
            var host = uri.Host;
            var portNum = uri.Port > 0 ? uri.Port : 5432;
            var database = uri.AbsolutePath.TrimStart('/');
            postgresConnStr = $"Host={host};Port={portNum};Database={database};Username={user};Password={password};SSL Mode=Require;Trust Server Certificate=true;";
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Database] Warning parsing PostgreSQL URI: {ex.Message}. Using raw string.");
            postgresConnStr = postgresUrl;
        }
    }
    else
    {
        postgresConnStr = postgresUrl;
    }
}

if (!string.IsNullOrWhiteSpace(postgresConnStr))
{
    Console.WriteLine("[Database] 🚀 Connected to Cloud PostgreSQL database (Permanent Cloud Storage)!");
    builder.Services.AddDbContext<AppDbContext>(opt =>
        opt.UseNpgsql(postgresConnStr));
}
else
{
    var baseDir = AppContext.BaseDirectory;
    var projectDirCandidate = Path.GetFullPath(Path.Combine(baseDir, "..", "..", "..", "quran.db"));
    var localApiCandidate = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "quran.db"));
    var baseDirCandidate = Path.GetFullPath(Path.Combine(baseDir, "quran.db"));
    var envDataDir = Environment.GetEnvironmentVariable("DATA_DIR") ?? Environment.GetEnvironmentVariable("PERSISTENT_DATA_PATH");

    string dbPath;
    if (!string.IsNullOrWhiteSpace(envDataDir))
    {
        Directory.CreateDirectory(envDataDir);
        dbPath = Path.Combine(envDataDir, "quran.db");
    }
    else if (File.Exists(projectDirCandidate))
    {
        dbPath = projectDirCandidate;
    }
    else if (File.Exists(localApiCandidate))
    {
        dbPath = localApiCandidate;
    }
    else
    {
        dbPath = baseDirCandidate;
    }

    Console.WriteLine($"[Database] Connected to local SQLite database at: {dbPath}");
    builder.Services.AddDbContext<AppDbContext>(opt =>
        opt.UseSqlite($"Data Source={dbPath};Cache=Shared;"));
}

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
                  if (string.IsNullOrWhiteSpace(origin) || origin.Equals("null", StringComparison.OrdinalIgnoreCase)) 
                      return true;

                  if (Uri.TryCreate(origin, UriKind.Absolute, out var uri))
                  {
                      return uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
                             uri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase) ||
                             allowedOrigins.Contains(origin, StringComparer.OrdinalIgnoreCase) ||
                             origin.EndsWith(".github.io", StringComparison.OrdinalIgnoreCase) ||
                             origin.EndsWith(".onrender.com", StringComparison.OrdinalIgnoreCase);
                  }
                  return true;
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
        Console.WriteLine($"[Database Status] Teachers: {db.Teachers.Count()}, Students: {db.Students.Count()}, Users: {db.Users.Count()}");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Database initialization notice: {ex.Message}");
    }
}

string? webDir = null;
try
{
    var candidates = new[]
    {
        Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "..", "..", "QuranCircles.Web")),
        Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "..", "..", "..", "QuranCircles.Web")),
        Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "QuranCircles.Web")),
        @"c:\xampp\htdocs\Quran Center\QuranCircles.Web"
    };

    webDir = candidates.FirstOrDefault(Directory.Exists);
    if (webDir != null)
    {
        var fileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(webDir);
        app.UseDefaultFiles(new DefaultFilesOptions { FileProvider = fileProvider });
        app.UseStaticFiles(new StaticFileOptions { FileProvider = fileProvider });
    }
}
catch { }

// Serve Flutter Mobile Web Build under /mobile/ path
try
{
    var mobileCandidates = new[]
    {
        Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "..", "..", "QuranCircles.Mobile", "build", "web")),
        Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "..", "..", "..", "QuranCircles.Mobile", "build", "web")),
        Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "QuranCircles.Mobile", "build", "web")),
        @"c:\xampp\htdocs\Quran Center\QuranCircles.Mobile\build\web"
    };

    var mobileDir = mobileCandidates.FirstOrDefault(Directory.Exists);
    if (mobileDir != null)
    {
        var mobileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(mobileDir);
        app.UseDefaultFiles(new DefaultFilesOptions
        {
            FileProvider = mobileProvider,
            RequestPath = "/mobile"
        });
        app.UseStaticFiles(new StaticFileOptions
        {
            FileProvider = mobileProvider,
            RequestPath = "/mobile"
        });
        app.MapGet("/mobile", () => Results.Redirect("/mobile/index.html"));
    }
}
catch { }


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
app.MapGet("/api/status", () => Results.Ok(new
{
    status = "online",
    center = "مركز البيان لتعليم القرآن الكريم وتدريس علومه",
    timestamp = DateTime.UtcNow,
    version = "1.1.0",
    engine = "ASP.NET Core 9.0 Enterprise Edition"
}));

if (webDir == null)
{
    app.MapGet("/", () => Results.Ok(new
    {
        status = "online",
        center = "مركز البيان لتعليم القرآن الكريم وتدريس علومه",
        timestamp = DateTime.UtcNow,
        version = "1.1.0",
        engine = "ASP.NET Core 9.0 Enterprise Edition"
    }));
}

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