using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class TokenService
{
    private readonly byte[] _keyBytes;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly int _expiryDays;

    public TokenService(IConfiguration configuration)
    {
        var secret = Environment.GetEnvironmentVariable("JWT_SECRET_KEY")
                     ?? configuration["Jwt:SecretKey"]
                     ?? "QuranCenterManagementSystemSuperSecretKeyForJWT2026!";
        _issuer = configuration["Jwt:Issuer"] ?? "QuranCenterApi";
        _audience = configuration["Jwt:Audience"] ?? "QuranCenterClients";
        _expiryDays = int.TryParse(configuration["Jwt:ExpiryDays"], out var exp) ? exp : 30;
        _keyBytes = Encoding.UTF8.GetBytes(secret);
    }

    public string GenerateToken(User user)
    {
        var header = new { alg = "HS256", typ = "JWT" };
        var headerJson = JsonSerializer.Serialize(header);
        var headerBase64 = Base64UrlEncode(Encoding.UTF8.GetBytes(headerJson));

        var expiry = DateTimeOffset.UtcNow.AddDays(_expiryDays).ToUnixTimeSeconds();
        var payload = new
        {
            sub = user.Id.ToString(),
            name = user.FullName ?? user.Username,
            username = user.Username,
            role = user.Role.ToString(),
            iss = _issuer,
            aud = _audience,
            exp = expiry,
            iat = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
        };
        var payloadJson = JsonSerializer.Serialize(payload);
        var payloadBase64 = Base64UrlEncode(Encoding.UTF8.GetBytes(payloadJson));

        var dataToSign = $"{headerBase64}.{payloadBase64}";
        var signature = ComputeHmac(dataToSign);

        return $"{dataToSign}.{signature}";
    }

    public bool ValidateToken(string token, out int userId, out UserRole role, out string username)
    {
        userId = 0;
        role = default;
        username = string.Empty;

        if (string.IsNullOrWhiteSpace(token)) return false;

        // Support Bearer prefix if present
        if (token.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            token = token.Substring(7).Trim();
        }

        var parts = token.Split('.');
        
        // 1. Standard 3-part JWT
        if (parts.Length == 3)
        {
            var dataToSign = $"{parts[0]}.{parts[1]}";
            var signature = parts[2];
            var expectedSignature = ComputeHmac(dataToSign);

            if (!CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(signature), Encoding.UTF8.GetBytes(expectedSignature)))
            {
                return false;
            }

            try
            {
                var payloadJson = Encoding.UTF8.GetString(Base64UrlDecode(parts[1]));
                using var doc = JsonDocument.Parse(payloadJson);
                var root = doc.RootElement;

                if (root.TryGetProperty("exp", out var expElem) && expElem.TryGetInt64(out var exp))
                {
                    if (DateTimeOffset.UtcNow.ToUnixTimeSeconds() > exp) return false; // Expired
                }

                if (root.TryGetProperty("sub", out var subElem) && int.TryParse(subElem.GetString(), out var id))
                {
                    userId = id;
                }
                else return false;

                if (root.TryGetProperty("username", out var userElem))
                {
                    username = userElem.GetString() ?? string.Empty;
                }

                if (root.TryGetProperty("role", out var roleElem) && Enum.TryParse<UserRole>(roleElem.GetString(), out var parsedRole))
                {
                    role = parsedRole;
                }
                else return false;

                return true;
            }
            catch
            {
                return false;
            }
        }

        // 2. Legacy 2-part token fallback for smooth migration
        if (parts.Length == 2)
        {
            var payloadBase64 = parts[0];
            var signature = parts[1];
            var expectedSignature = ComputeHmac(payloadBase64);

            if (!CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(signature), Encoding.UTF8.GetBytes(expectedSignature)))
            {
                return false;
            }

            try
            {
                var payload = Encoding.UTF8.GetString(Convert.FromBase64String(payloadBase64));
                var pieces = payload.Split(':');
                if (pieces.Length != 4) return false;

                userId = int.Parse(pieces[0]);
                username = pieces[1];
                role = Enum.Parse<UserRole>(pieces[2]);
                var expiryTicks = long.Parse(pieces[3]);

                return DateTime.UtcNow.Ticks <= expiryTicks;
            }
            catch
            {
                return false;
            }
        }

        return false;
    }

    private string ComputeHmac(string input)
    {
        using var hmac = new HMACSHA256(_keyBytes);
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(input));
        return Base64UrlEncode(hash);
    }

    private static string Base64UrlEncode(byte[] input)
    {
        return Convert.ToBase64String(input)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static byte[] Base64UrlDecode(string input)
    {
        var output = input.Replace('-', '+').Replace('_', '/');
        switch (output.Length % 4)
        {
            case 2: output += "=="; break;
            case 3: output += "="; break;
        }
        return Convert.FromBase64String(output);
    }
}
