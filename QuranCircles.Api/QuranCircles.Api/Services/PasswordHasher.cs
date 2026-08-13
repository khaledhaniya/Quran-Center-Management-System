using Microsoft.AspNetCore.Identity;

namespace QuranCircles.Api.Services;

public class PasswordHasher
{
    private readonly PasswordHasher<string> _hasher = new();

    public string HashPassword(string password)
    {
        return _hasher.HashPassword("user", password);
    }

    public bool VerifyPassword(string hashedPassword, string password)
    {
        var result = _hasher.VerifyHashedPassword("user", hashedPassword, password);
        return result == PasswordVerificationResult.Success;
    }
}
