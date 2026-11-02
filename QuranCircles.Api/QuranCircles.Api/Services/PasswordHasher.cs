using Microsoft.AspNetCore.Identity;

namespace QuranCircles.Api.Services;

public class PasswordHasher
{
    public const string DefaultNewAccountPassword = "123456";
    public const int MinimumPasswordLength = 6;
    public static string NewAccountPassword(string? password = null) =>
        string.IsNullOrWhiteSpace(password) ? DefaultNewAccountPassword : password.Trim();
    public static string? PasswordError(string? password) =>
        !string.IsNullOrWhiteSpace(password) && password.Trim().Length < MinimumPasswordLength
        ? "كلمة المرور يجب أن تتكون من 6 أحرف على الأقل." : null;
    private readonly PasswordHasher<string> _hasher = new(Microsoft.Extensions.Options.Options.Create(new PasswordHasherOptions { IterationCount = 210_000 }));

    public static string GenerateTemporaryPassword() => Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(24));

    public string HashPassword(string password)
    {
        return _hasher.HashPassword("user", password);
    }

    public bool VerifyPassword(string hashedPassword, string password)
    {
        var result = _hasher.VerifyHashedPassword("user", hashedPassword, password);
        return result != PasswordVerificationResult.Failed;
    }
}
