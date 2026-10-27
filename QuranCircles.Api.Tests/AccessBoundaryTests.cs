using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using QuranCircles.Api.Controllers;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using Xunit;

namespace QuranCircles.Api.Tests;

public class AccessBoundaryTests
{
    private static AppDbContext Open(SqliteConnection connection)
    {
        connection.Open();
        var db=new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(connection).Options);
        db.Database.EnsureCreated();return db;
    }
    private static DefaultHttpContext Context(User user)
    {
        var ctx=new DefaultHttpContext();ctx.Items["QuranCenter.VerifiedUser"]=user;return ctx;
    }

    [Theory]
    [InlineData("/api/students/1")]
    [InlineData("/API/users")]
    [InlineData("/api/auth/login/extra")]
    public async Task AnonymousApiRequestsAreDeniedBeforeTheHandler(string path)
    {
        var ctx=new DefaultHttpContext();ctx.Request.Path=path;ctx.Response.Body=new MemoryStream();var called=false;
        await WebRequestPolicy.Apply(ctx,_=>{called=true;return Task.CompletedTask;});
        Assert.Equal(401,ctx.Response.StatusCode);Assert.False(called);
        Assert.Contains("no-store",ctx.Response.Headers.CacheControl.ToString());
    }

    [Theory]
    [InlineData("/appsettings.Production.json")]
    [InlineData("/App_Data/quran.db")]
    [InlineData("/.git/config")]
    [InlineData("/logs/stdout.log")]
    public async Task ConfigurationDatabaseAndLogsCannotBeDownloaded(string path)
    {
        var ctx=new DefaultHttpContext();ctx.Request.Path=path;
        await WebRequestPolicy.Apply(ctx,_=>throw new Exception("Private file reached the handler"));
        Assert.Equal(404,ctx.Response.StatusCode);Assert.Equal("nosniff",ctx.Response.Headers.XContentTypeOptions);
    }

    [Fact]
    public void SqliteNativeRuntimeIncludesTheSecurityFix()
    {
        using var connection=new SqliteConnection("Data Source=:memory:");connection.Open();
        Assert.True(Version.Parse(connection.ServerVersion)>=new Version(3,50,2));
    }

    [Fact]
    public void VersionedAssetsAreReusableButHtmlAndApiAreNotImmutable()
    {
        var ctx=new DefaultHttpContext();ctx.Request.Path="/app.js";ctx.Request.QueryString=new QueryString("?v=release-2");
        Assert.Contains("immutable",WebRequestPolicy.StaticCache(ctx.Request));
        ctx.Request.Path="/index.html";Assert.DoesNotContain("immutable",WebRequestPolicy.StaticCache(ctx.Request));
        ctx.Request.Path="/api/auth/login";ctx.Request.Method="POST";Assert.True(WebRequestPolicy.IsPublicApi(ctx.Request));
        ctx.Request.Path="/api/settings";Assert.False(WebRequestPolicy.IsPublicApi(ctx.Request));
    }

    [Fact]
    public async Task ATeacherCannotReadAnotherCirclesStudentOrRecitationRecords()
    {
        using var connection=new SqliteConnection("Data Source=:memory:");using var db=Open(connection);
        db.Teachers.AddRange(new Teacher {Id=1,FullName="الأول",TaskRole="معلم حلقة"},new Teacher {Id=2,FullName="الثاني",TaskRole="معلم حلقة"});
        var user=new User {Id=1,Username="teacher",Role=UserRole.Teacher,TeacherId=1};db.Users.Add(user);
        db.Circles.AddRange(new Circle {Id=1,Name="الأولى",TeacherId=1},new Circle {Id=2,Name="الثانية",TeacherId=2});
        db.Students.AddRange(new Student {Id=1,FullName="أحمد",CircleId=1},new Student {Id=2,FullName="محمد",CircleId=2});
        await db.SaveChangesAsync();var context=Context(user);var access=new StudentReadAccess(db);
        Assert.True(await access.CanReadAsync(context,1));Assert.False(await access.CanReadAsync(context,2));
        var controller=new SessionsController(new SessionService(db),db) { ControllerContext=new ControllerContext {HttpContext=context} };
        Assert.IsType<ForbidResult>(await controller.GetByStudent(2));
        user.Role=UserRole.Parent;user.TeacherId=null;await db.SaveChangesAsync();
        Assert.False(await access.CanReadAsync(context,1));
        (await db.Students.FindAsync(1))!.ParentId=1;await db.SaveChangesAsync();
        Assert.True(await access.CanReadAsync(context,1));Assert.False(await access.CanReadAsync(context,2));
    }

    [Fact]
    public async Task DeveloperOnlyCanViewEncryptedPasswordAfterResetAndUserChange()
    {
        using var connection=new SqliteConnection("Data Source=:memory:");using var db=Open(connection);
        var hasher=new PasswordHasher();var developer=new User {Id=1,Username="dev",Role=UserRole.Developer,PasswordHash=hasher.HashPassword("developer-current")};
        var target=new User {Id=2,Username="student",Role=UserRole.Student,PasswordHash=hasher.HashPassword("old-password")};
        db.Users.AddRange(developer,target);await db.SaveChangesAsync();
        var tokens=new TokenService(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?> { ["Jwt:SecretKey"]="only-testing-key-with-more-than-thirty-two-bytes" }).Build());
        var vault=new PasswordVault(tokens);
        var oldToken=tokens.GenerateToken(target);var controller=new UsersController(db,hasher,vault) {ControllerContext=new ControllerContext {HttpContext=Context(developer)}};
        Assert.IsType<BadRequestObjectResult>(await controller.ResetPassword(2,new("incorrect")));
        Assert.True(tokens.ValidateTokenForUser(oldToken,target));
        var result=Assert.IsType<OkObjectResult>(await controller.ResetPassword(2,new("developer-current")));
        var json=System.Text.Json.JsonSerializer.SerializeToElement(result.Value);var password=json.GetProperty("password").GetString()!;
        Assert.True(hasher.VerifyPassword(target.PasswordHash,password));Assert.False(tokens.ValidateTokenForUser(oldToken,target));
        Assert.Empty(target.PlainPassword);Assert.DoesNotContain(password,System.Text.Json.JsonSerializer.Serialize(target));
        Assert.DoesNotContain(password,target.PasswordCiphertext);
        Assert.Equal(password,vault.Unprotect(target.PasswordCiphertext));
        Assert.DoesNotContain(password,(await db.AuditLogs.SingleAsync()).Details);
        var devList=System.Text.Json.JsonSerializer.SerializeToElement(Assert.IsType<OkObjectResult>(await controller.GetAll()).Value);
        Assert.Equal(password,devList.EnumerateArray().Single(x=>x.GetProperty("Id").GetInt32()==2).GetProperty("PlainPassword").GetString());
        var selfService=new AuthController(db,hasher,tokens,new ReportService(db),vault) {ControllerContext=new ControllerContext {HttpContext=Context(target)}};
        Assert.IsType<OkObjectResult>(await selfService.ChangePassword(new(password,"changed-by-student")));
        devList=System.Text.Json.JsonSerializer.SerializeToElement(Assert.IsType<OkObjectResult>(await controller.GetAll()).Value);
        Assert.Equal("changed-by-student",devList.EnumerateArray().Single(x=>x.GetProperty("Id").GetInt32()==2).GetProperty("PlainPassword").GetString());
        var admin=new User {Id=3,Username="admin",Role=UserRole.Admin,IsActive=true};db.Users.Add(admin);await db.SaveChangesAsync();
        controller.ControllerContext.HttpContext=Context(admin);
        var adminList=System.Text.Json.JsonSerializer.SerializeToElement(Assert.IsType<OkObjectResult>(await controller.GetAll()).Value);
        Assert.Equal(System.Text.Json.JsonValueKind.Null,adminList.EnumerateArray().Single(x=>x.GetProperty("Id").GetInt32()==2).GetProperty("PlainPassword").ValueKind);
        controller.ControllerContext.HttpContext=Context(target);
        Assert.IsType<ForbidResult>(await controller.ResetPassword(1,new("old-password")));
    }

    [Fact]
    public async Task ExistingPasswordAppearsAfterItsOwnerSignsInWithoutChangingTheHash()
    {
        using var connection=new SqliteConnection("Data Source=:memory:");using var db=Open(connection);
        var hasher=new PasswordHasher();var originalHash=hasher.HashPassword("older-user-password");
        var user=new User {Id=1,Username="student",FullName="طالب",Role=UserRole.Student,PasswordHash=originalHash};
        db.Users.Add(user);await db.SaveChangesAsync();
        var tokens=new TokenService(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?> { ["Jwt:SecretKey"]="only-testing-key-with-more-than-thirty-two-bytes" }).Build());
        var vault=new PasswordVault(tokens);
        var auth=new AuthController(db,hasher,tokens,new ReportService(db),vault) {ControllerContext=new ControllerContext {HttpContext=new DefaultHttpContext()}};
        Assert.IsType<OkObjectResult>(await auth.Login(new("student","older-user-password")));
        Assert.Equal(originalHash,user.PasswordHash);
        Assert.Equal("older-user-password",vault.Unprotect(user.PasswordCiphertext));
        var otherKey=new TokenService(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?> { ["Jwt:SecretKey"]="another-testing-key-with-more-than-thirty-two-bytes" }).Build());
        Assert.Null(new PasswordVault(otherKey).Unprotect(user.PasswordCiphertext));
    }

    [Fact]
    public async Task AdminCannotUseANumericRoleToPromoteAUserToDeveloperOrDisableTheDeveloper()
    {
        using var connection=new SqliteConnection("Data Source=:memory:");using var db=Open(connection);
        var actor=new User {Id=1,Username="admin",Role=UserRole.Admin};
        var developer=new User {Id=2,Username="dev",Role=UserRole.Developer};
        var target=new User {Id=3,Username="student",Role=UserRole.Student};
        db.Users.AddRange(actor,developer,target);await db.SaveChangesAsync();
        var controller=new UsersController(db,new PasswordHasher()) { ControllerContext=new ControllerContext {HttpContext=Context(actor)} };
        var result=Assert.IsType<ObjectResult>(await controller.Update(3,new("student","الطالب",((int)UserRole.Developer).ToString())));
        Assert.Equal(403,result.StatusCode);Assert.Equal(UserRole.Student,target.Role);
        result=Assert.IsType<ObjectResult>(await controller.ToggleStatus(2));
        Assert.Equal(403,result.StatusCode);Assert.True(developer.IsActive);
    }

    [Fact]
    public async Task AnAdminCannotChangeTheirOwnPasswordWithoutTheCurrentPassword()
    {
        using var connection=new SqliteConnection("Data Source=:memory:");using var db=Open(connection);
        var hasher=new PasswordHasher();var user=new User {Id=1,Username="admin",Role=UserRole.Admin,PasswordHash=hasher.HashPassword("current-password")};db.Users.Add(user);await db.SaveChangesAsync();
        var tokens=new TokenService(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?> { ["Jwt:SecretKey"]="only-testing-key-with-more-than-thirty-two-bytes" }).Build());
        var controller=new AuthController(db,hasher,tokens,new ReportService(db)) { ControllerContext=new ControllerContext {HttpContext=Context(user)} };
        Assert.IsType<BadRequestObjectResult>(await controller.ChangePassword(new(null,"different-password")));
        Assert.True(hasher.VerifyPassword(user.PasswordHash,"current-password"));
    }
}
