using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Controllers;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using Xunit;

namespace QuranCircles.Api.Tests;

public class RegistrationRulesTests
{
    [Fact]
    public void IdentityComparisonRequiresAllNineDigitsToMatch()
    {
        Assert.False(RegistrationRules.SameIdentity("123456789", "123456788"));
        Assert.False(RegistrationRules.SameIdentity("1", "1"));
        Assert.True(RegistrationRules.SameIdentity("١٢٣٤٥٦٧٨٩", "123456789"));
        Assert.NotNull(RegistrationRules.IdentityError("12345678", "الهوية"));
        Assert.NotNull(RegistrationRules.IdentityError("1234567890", "الهوية"));
    }

    [Theory]
    [InlineData("0591234567", true)]
    [InlineData("0561234567", true)]
    [InlineData("٠٥٩١٢٣٤٥٦٧", true)]
    [InlineData("0571234567", false)]
    [InlineData("059123456", false)]
    [InlineData("05912345678", false)]
    public void LocalPhoneHasAnExactLengthAndSupportedPrefix(string value, bool valid) =>
        Assert.Equal(valid, RegistrationRules.PhoneError(value, true) == null);

    [Theory]
    [InlineData("+972591234567", "+972591234567")]
    [InlineData("00970591234567", "+970591234567")]
    [InlineData("0591234567", "+970591234567")]
    [InlineData("", "")]
    public void WhatsAppKeepsTheCountryCodeAndRemainsOptional(string value, string expected)
    {
        Assert.Equal(expected, RegistrationRules.WhatsApp(value));
        Assert.Null(RegistrationRules.WhatsAppError(value));
        Assert.NotNull(RegistrationRules.WhatsAppError("+971591234567"));
    }

    private static AppDbContext Open(SqliteConnection connection)
    {
        connection.Open();
        var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(connection).Options);
        db.Database.EnsureCreated(); return db;
    }

    [Fact]
    public async Task NearlyMatchingStudentAndGuardianIdentitiesRegisterWithTheDefaultPassword()
    {
        using var connection = new SqliteConnection("Data Source=:memory:"); using var db = Open(connection);
        var hasher = new PasswordHasher();
        var service = new StudentService(db, hasher);
        var (student, parent, error) = await service.CreateAsync(new CreateStudentDto(
            "طالب جديد", null, null, "0591234567", null, null, null, null,
            StudentIdentityNumber: "123456789", ParentIdentityNumber: "123456788", ParentName: "ولي الأمر"));
        Assert.Null(error); Assert.NotNull(student); Assert.NotNull(parent);
        var studentUser = await db.Users.SingleAsync(u => u.StudentId == student!.Id);
        Assert.True(hasher.VerifyPassword(studentUser.PasswordHash, "123456"));
        Assert.True(hasher.VerifyPassword(parent!.PasswordHash, "123456"));
        Assert.Empty(studentUser.PlainPassword);
    }

    [Fact]
    public async Task UserCreationDefaultsToSixDigitsAndRejectsAShorterCustomPassword()
    {
        using var connection = new SqliteConnection("Data Source=:memory:"); using var db = Open(connection);
        var hasher = new PasswordHasher();
        var context = new DefaultHttpContext();
        context.Items["QuranCenter.VerifiedUser"] = new User { Id = 100, Role = UserRole.Developer };
        var users = new UsersController(db, hasher) { ControllerContext = new ControllerContext { HttpContext = context } };
        Assert.IsType<CreatedAtActionResult>(await users.Create(new("new-account", "مستخدم", "Parent")));
        var account = await db.Users.SingleAsync(u => u.Username == "new-account");
        Assert.True(hasher.VerifyPassword(account.PasswordHash, "123456"));
        Assert.IsType<CreatedAtActionResult>(await users.Create(new("custom-six", "مستخدم", "Parent", "abcdef")));
        Assert.IsType<BadRequestObjectResult>(await users.Create(new("too-short", "مستخدم", "Parent", "12345")));
        Assert.False(await db.Users.AnyAsync(u => u.Username == "too-short"));
    }

    [Fact]
    public async Task TeacherAccountsUseTheDefaultAndPasswordChangesAcceptSixCharacters()
    {
        using var connection = new SqliteConnection("Data Source=:memory:"); using var db = Open(connection);
        var hasher = new PasswordHasher();
        var service = new TeacherService(db, hasher);
        var (teacher, error) = await service.CreateAsync(new CreateTeacherDto(
            "معلم جديد", null, null, "0561234567", null, null, IdentityNumber: "987654321"));
        Assert.Null(error);
        var user = await db.Users.SingleAsync(u => u.TeacherId == teacher!.Id);
        Assert.True(hasher.VerifyPassword(user.PasswordHash, "123456"));
        var context = new DefaultHttpContext(); context.Items["QuranCenter.VerifiedUser"] = user;
        var auth = new AuthController(db, hasher, null!, null!) {
            ControllerContext = new ControllerContext { HttpContext = context } };
        Assert.IsType<BadRequestObjectResult>(await auth.ChangePassword(new("123456", "12345")));
        Assert.IsType<OkObjectResult>(await auth.ChangePassword(new("123456", "abcdef")));
        Assert.True(hasher.VerifyPassword(user.PasswordHash, "abcdef"));
    }

    [Fact]
    public async Task AutoCreatedCourseSupervisorAlsoReceivesTheDefaultPassword()
    {
        using var connection = new SqliteConnection("Data Source=:memory:"); using var db = Open(connection);
        var teacher = new Teacher { FullName = "مشرف دورة", IdentityNumber = "987654321", IsActive = true };
        db.Teachers.Add(teacher); await db.SaveChangesAsync();
        var context = new DefaultHttpContext();
        context.Items["QuranCenter.VerifiedUser"] = new User { Id = 100, Role = UserRole.Developer };
        var courses = new CoursesController(db) { ControllerContext = new ControllerContext { HttpContext = context } };
        Assert.IsType<CreatedAtActionResult>(await courses.Create(new("دورة", null, null, teacher.Id)));
        var account = await db.Users.SingleAsync(u => u.TeacherId == teacher.Id);
        Assert.True(new PasswordHasher().VerifyPassword(account.PasswordHash, "123456"));
    }
}
