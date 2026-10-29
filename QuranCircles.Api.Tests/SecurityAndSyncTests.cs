using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Routing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using Xunit;

namespace QuranCircles.Api.Tests;

public class SecurityAndSyncTests
{
    private static ServiceProvider Services()
    {
        var connection = new SqliteConnection("Data Source=:memory:");
        connection.Open();
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> {
            ["Jwt:SecretKey"] = "test-only-signing-key-with-at-least-thirty-two-bytes"
        }).Build();
        var services = new ServiceCollection();
        services.AddSingleton(connection);
        services.AddSingleton<IConfiguration>(config);
        services.AddSingleton<TokenService>();
        services.AddDbContext<AppDbContext>(options => options.UseSqlite(connection));
        services.AddLogging();
        services.AddControllers();
        return services.BuildServiceProvider();
    }

    private static User AddUser(AppDbContext db, UserRole role = UserRole.Teacher)
    {
        db.Database.EnsureCreated();
        var user = new User { Username = "teacher", FullName = "معلم", Role = role,
            PasswordHash = new PasswordHasher().HashPassword("original-password") };
        db.Users.Add(user);
        db.SaveChanges();
        return user;
    }

    [Fact]
    public void PasswordsAreHashedAndNeverSerialized()
    {
        using var services = Services();
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Database.EnsureCreated();
        var user = new User { Username = "legacy", PlainPassword = "legacy-secret", Role = UserRole.Student };
        db.Users.Add(user); db.SaveChanges();
        Assert.Empty(user.PlainPassword);
        Assert.True(new PasswordHasher().VerifyPassword(user.PasswordHash, "legacy-secret"));
        Assert.DoesNotContain("legacy-secret", System.Text.Json.JsonSerializer.Serialize(user));
        Assert.DoesNotContain("PlainPassword", System.Text.Json.JsonSerializer.Serialize(user));
        Assert.DoesNotContain("PasswordHash", System.Text.Json.JsonSerializer.Serialize(user));
    }

    [Fact]
    public void PasswordChangeAndDisableRevokeExistingToken()
    {
        using var services = Services();
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = AddUser(db);
        var tokens = services.GetRequiredService<TokenService>();
        var token = tokens.GenerateToken(user);
        Assert.True(tokens.ValidateTokenForUser(token, user));
        user.IsActive = false;
        db.SaveChanges();
        Assert.False(tokens.ValidateTokenForUser(token, user));
        user.IsActive = true;
        db.SaveChanges();
        Assert.False(tokens.ValidateTokenForUser(token, user));
        user.PasswordHash = new PasswordHasher().HashPassword("new-password");
        Assert.False(tokens.ValidateTokenForUser(token, user));
        Assert.True(tokens.ValidateTokenForUser(tokens.GenerateToken(user), user));
        Assert.False(tokens.ValidateToken(token + "tampered", out _, out _, out _));
    }

    [Fact]
    public void TeacherWithoutChildrenCannotAssumeParentRole()
    {
        using var services = Services(); using var scope = services.CreateScope();
        var user = AddUser(scope.ServiceProvider.GetRequiredService<AppDbContext>());
        var http = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
        http.Request.Headers.Authorization = "Bearer " + services.GetRequiredService<TokenService>().GenerateToken(user);
        var action = new ActionContext(http, new RouteData(), new ActionDescriptor(), new ModelStateDictionary());
        var authorization = new AuthorizationFilterContext(action, new List<IFilterMetadata>());
        new RequireRoleAttribute(UserRole.Parent).OnAuthorization(authorization);
        Assert.Equal(403, Assert.IsType<ObjectResult>(authorization.Result).StatusCode);
    }

    [Fact]
    public async Task RetryDoesNotRepeatMutationAndRejectsChangedPayload()
    {
        using var services = Services(); using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = AddUser(db);
        var http = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
        http.Request.Path = "/api/announcements";
        http.Request.Headers.Authorization = "Bearer " + services.GetRequiredService<TokenService>().GenerateToken(user);
        http.Request.Headers["Idempotency-Key"] = "retry-operation";
        var action = new ActionContext(http, new RouteData(), new ActionDescriptor(), new ModelStateDictionary());
        ActionExecutingContext Context(string title) => new(action, new List<IFilterMetadata>(),
            new Dictionary<string, object?> { ["title"] = title }, new object());
        var calls = 0;
        async Task<ActionExecutedContext> Mutate()
        {
            calls++;
            db.Announcements.Add(new Announcement { Title = "test", Content = "saved once" });
            await db.SaveChangesAsync();
            return new ActionExecutedContext(action, new List<IFilterMetadata>(), new object()) { Result = new OkObjectResult(new { saved = true }) };
        }
        var filter = new IdempotentAttribute();
        await filter.OnActionExecutionAsync(Context("test"), Mutate);
        var retry = Context("test");
        await filter.OnActionExecutionAsync(retry, Mutate);
        Assert.IsType<ContentResult>(retry.Result);
        Assert.Equal(1, calls);
        Assert.Equal(1, await db.Announcements.CountAsync());
        var conflict = Context("different");
        await filter.OnActionExecutionAsync(conflict, Mutate);
        Assert.IsType<ConflictObjectResult>(conflict.Result);
        Assert.Equal(1, calls);
    }

    [Fact]
    public async Task NoContentMutationIsCommittedAndRetryIsNotRepeated()
    {
        using var services = Services(); using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = AddUser(db);
        var http = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
        http.Request.Path = "/api/circles/1/students";
        http.Request.Headers.Authorization = "Bearer " + services.GetRequiredService<TokenService>().GenerateToken(user);
        http.Request.Headers["Idempotency-Key"] = "assign-student-once";
        var action = new ActionContext(http, new RouteData(), new ActionDescriptor(), new ModelStateDictionary());
        ActionExecutingContext Context() => new(action, new List<IFilterMetadata>(),
            new Dictionary<string, object?> { ["studentId"] = 12 }, new object());
        var calls = 0;
        async Task<ActionExecutedContext> Mutate()
        {
            calls++;
            db.Announcements.Add(new Announcement { Title = "assignment", Content = "committed" });
            await db.SaveChangesAsync();
            return new ActionExecutedContext(action, new List<IFilterMetadata>(), new object()) { Result = new NoContentResult() };
        }
        var filter = new IdempotentAttribute();
        await filter.OnActionExecutionAsync(Context(), Mutate);
        Assert.Equal(1, await db.Announcements.CountAsync());
        Assert.Equal(1, await db.IdempotencyReceipts.CountAsync());
        var retry = Context();
        await filter.OnActionExecutionAsync(retry, Mutate);
        Assert.IsType<NoContentResult>(retry.Result);
        Assert.Equal(1, calls);
        Assert.Equal(1, await db.Announcements.CountAsync());
    }

    [Fact]
    public async Task UnconfiguredSmsNeverReportsSuccess()
    {
        using var services = Services(); using var scope = services.CreateScope();
        using var http = new HttpClient();
        var gateway = new SmsGateway(http, services.GetRequiredService<IConfiguration>());
        var controller = new QuranCircles.Api.Controllers.SmsController(scope.ServiceProvider.GetRequiredService<AppDbContext>(), gateway);
        var result = await controller.SendSms(new(1, null, "test"));
        Assert.Equal(503, Assert.IsType<ObjectResult>(result).StatusCode);
    }

    [Fact]
    public void FullQuranCompletionRequiresAllThirtyDistinctParts()
    {
        Assert.False(ReportService.HasCompletedQuran(new Student { CompletedAjzaa = "30", PreviousQuranMemorization = "الجزء 30" }));
        Assert.False(ReportService.HasCompletedQuran(new Student { CompletedAjzaa = string.Join(',', Enumerable.Repeat(30, 30)) }));
        Assert.False(ReportService.HasCompletedQuran(new Student { PreviousQuranMemorization = "غير كامل" }));
        Assert.True(ReportService.HasCompletedQuran(new Student { CompletedAjzaa = string.Join(',', Enumerable.Range(1, 30)) }));
        Assert.Equal(0, ReportService.Percentage(0, 0));
        Assert.Equal(25, ReportService.Percentage(1, 4));
    }

    [Fact]
    public async Task EmptyDashboardNeverInventsAttendanceOrMemorization()
    {
        using var services = Services(); using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Database.EnsureCreated();
        var today = DateOnly.FromDateTime(DateTime.Today);
        var report = await new ReportService(db).GetExecutiveDashboardAsync(today, today);
        using var json = System.Text.Json.JsonDocument.Parse(System.Text.Json.JsonSerializer.Serialize(report));
        var root = json.RootElement;
        Assert.Equal(0, root.GetProperty("todayAttendanceRate").GetDouble());
        Assert.Equal(0, root.GetProperty("examPassRate").GetDouble());
        var flow = root.GetProperty("quranicFlow");
        Assert.Equal(0, flow.GetProperty("dailyAveragePages").GetDouble());
        Assert.Equal(0, flow.GetProperty("reviewRatio").GetDouble());
        Assert.Equal(0, flow.GetProperty("newMemorizationRatio").GetDouble());
    }

    [Fact]
    public async Task SensitiveActionRequiresActualAccountPassword()
    {
        using var services = Services(); using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = AddUser(db);
        var http = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
        http.Request.Headers.Authorization = "Bearer " + services.GetRequiredService<TokenService>().GenerateToken(user);
        Assert.False(await SensitiveActionVerifier.VerifyAsync(http, db, null));
        Assert.False(await SensitiveActionVerifier.VerifyAsync(http, db, "123456"));
        Assert.True(await SensitiveActionVerifier.VerifyAsync(http, db, "original-password"));
    }

    [Fact]
    public void AdministratorCannotAssumeDeveloperOnlyAccess()
    {
        using var services = Services(); using var scope = services.CreateScope();
        var user = AddUser(scope.ServiceProvider.GetRequiredService<AppDbContext>(), UserRole.Admin);
        var http = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
        http.Request.Headers.Authorization = "Bearer " + services.GetRequiredService<TokenService>().GenerateToken(user);
        var action = new ActionContext(http, new RouteData(), new ActionDescriptor(), new ModelStateDictionary());
        var authorization = new AuthorizationFilterContext(action, new List<IFilterMetadata>());
        new RequireRoleAttribute(UserRole.Developer).OnAuthorization(authorization);
        Assert.Equal(403, Assert.IsType<ObjectResult>(authorization.Result).StatusCode);
    }

    [Fact]
    public void SchemaUpgradePreservesPasswordAndErasesLegacyPlaintext()
    {
        using var services = Services(); using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = AddUser(db, UserRole.Admin);
        user.Username = "admin";
        db.SaveChanges();
        var originalHash = user.PasswordHash;
        db.Database.ExecuteSqlInterpolated($"UPDATE Users SET PlainPassword={"old-plaintext-value"} WHERE Id={user.Id}");
        db.Database.ExecuteSqlRaw("ALTER TABLE Users DROP COLUMN TokenVersion");
        db.ChangeTracker.Clear();
        DbSeeder.MigrateSchema(db);
        var upgraded = db.Users.AsNoTracking().Single(u => u.Id == user.Id);
        Assert.Equal(originalHash, upgraded.PasswordHash);
        Assert.Empty(upgraded.PlainPassword);
        Assert.Equal(0, upgraded.TokenVersion);
        Assert.True(new PasswordHasher().VerifyPassword(upgraded.PasswordHash, "original-password"));
    }
}
