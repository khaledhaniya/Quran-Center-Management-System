using Microsoft.AspNetCore.Identity;

namespace QuranCircles.Api.Services;

public class PasswordHasher
{
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
