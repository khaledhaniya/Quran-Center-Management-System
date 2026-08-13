using System.Security.Cryptography;
using System.Text;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class TokenService
{
    private const string Secret = "quran_circles_super_secret_key_2026_ramadan_eid_mubarak";
    private static readonly byte[] KeyBytes = Encoding.UTF8.GetBytes(Secret);

    public string GenerateToken(User user)
    {
        var expiry = DateTime.UtcNow.AddDays(7).Ticks;
        var payload = $"{user.Id}:{user.Username}:{user.Role}:{expiry}";
        var payloadBase64 = Convert.ToBase64String(Encoding.UTF8.GetBytes(payload));
        
        var signature = ComputeHmac(payloadBase64);
        return $"{payloadBase64}.{signature}";
    }

    public bool ValidateToken(string token, out int userId, out UserRole role, out string username)
    {
        userId = 0;
        role = default;
        username = string.Empty;

        if (string.IsNullOrWhiteSpace(token)) return false;

        var parts = token.Split('.');
        if (parts.Length != 2) return false;

        var payloadBase64 = parts[0];
        var signature = parts[1];

        // Verify signature
        var expectedSignature = ComputeHmac(payloadBase64);
        if (signature != expectedSignature) return false;

        try
        {
            var payload = Encoding.UTF8.GetString(Convert.FromBase64String(payloadBase64));
            var pieces = payload.Split(':');
            if (pieces.Length != 4) return false;

            var idVal = int.Parse(pieces[0]);
            var userVal = pieces[1];
            var roleVal = Enum.Parse<UserRole>(pieces[2]);
            var expiryTicks = long.Parse(pieces[3]);

            if (DateTime.UtcNow.Ticks > expiryTicks) return false; // Expired

            userId = idVal;
            username = userVal;
            role = roleVal;
            return true;
        }
        catch
        {
            return false;
        }
    }

    private string ComputeHmac(string input)
    {
        using var hmac = new HMACSHA256(KeyBytes);
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(input));
        return Convert.ToBase64String(hash);
    }
}
