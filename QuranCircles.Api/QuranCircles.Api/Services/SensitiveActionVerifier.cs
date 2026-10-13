using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;

namespace QuranCircles.Api.Services;

public static class SensitiveActionVerifier
{
    public static async Task<bool> VerifyAsync(HttpContext context, AppDbContext db, string? bodyPassword)
    {
        var userId = FakeAuth.GetUserId(context);
        if (!userId.HasValue) return false;
        var password = context.Request.Headers["X-Confirm-Password"].FirstOrDefault()
            ?? context.Request.Headers["X-2FA-Code"].FirstOrDefault() ?? bodyPassword;
        if (string.IsNullOrEmpty(password)) return false;
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId && u.IsActive);
        return user != null && new PasswordHasher().VerifyPassword(user.PasswordHash, password);
    }
}
