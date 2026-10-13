using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
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
        var secret = Environment.GetEnvironmentVariable("JWT_SECRET_KEY") ?? configuration["Jwt:SecretKey"];
        // Keys previously committed in public source must not remain signing credentials.
        var exposedKeyFingerprints = new[] { "A8DCF23B8DE841540AC5FBFA9CF82697349977E8E7122F0E86B5BC720E2C58D7" };
        if (!string.IsNullOrEmpty(secret) && exposedKeyFingerprints.Contains(Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(secret)))))
            secret = null;
        if (!string.IsNullOrWhiteSpace(secret))
        {
            if (Encoding.UTF8.GetByteCount(secret) < 32)
                throw new InvalidOperationException("JWT_SECRET_KEY must contain at least 32 bytes.");
            _keyBytes = Encoding.UTF8.GetBytes(secret);
        }
        else
        {
            // A persistent machine-local key replaces the public hardcoded default.
            // Cloud deployments should set JWT_SECRET_KEY in their secret store.
            var defaultKeyDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "QuranCenter", "keys");
            if (Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Production")
            {
                defaultKeyDirectory = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "App_Data"));
                try { Directory.CreateDirectory(defaultKeyDirectory); }
                catch (UnauthorizedAccessException) { defaultKeyDirectory = Path.Combine(AppContext.BaseDirectory, "App_Data"); }
            }
            var path = Environment.GetEnvironmentVariable("JWT_KEY_FILE") ?? Path.Combine(defaultKeyDirectory, "signing-key.bin");
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
            try
            {
                using var file = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
                var bytes = RandomNumberGenerator.GetBytes(64);
                file.Write(bytes);
                if (!OperatingSystem.IsWindows()) File.SetUnixFileMode(path, UnixFileMode.UserRead | UnixFileMode.UserWrite);
            }
            catch (IOException) when (File.Exists(path)) { }
            _keyBytes = File.ReadAllBytes(path);
            if (_keyBytes.Length < 32) throw new InvalidOperationException("Invalid stored signing key.");
        }
        _issuer = configuration["Jwt:Issuer"] ?? "QuranCenterApi";
        _audience = configuration["Jwt:Audience"] ?? "QuranCenterClients";
        _expiryDays = int.TryParse(configuration["Jwt:ExpiryDays"], out var days) ? Math.Clamp(days, 1, 30) : 7;
    }

    public string GenerateToken(User user)
    {
        var header = Encode(JsonSerializer.SerializeToUtf8Bytes(new { alg = "HS256", typ = "JWT" }));
        var payload = Encode(JsonSerializer.SerializeToUtf8Bytes(new {
            sub = user.Id.ToString(), name = user.FullName ?? user.Username, username = user.Username,
            role = user.Role.ToString(), iss = _issuer, aud = _audience,
            exp = DateTimeOffset.UtcNow.AddDays(_expiryDays).ToUnixTimeSeconds(),
            iat = DateTimeOffset.UtcNow.ToUnixTimeSeconds(), stamp = Sign($"{user.PasswordHash}:{user.TokenVersion}")
        }));
        return $"{header}.{payload}.{Sign($"{header}.{payload}")}";
    }

    public bool ValidateToken(string token, out int userId, out UserRole role, out string username)
    {
        userId = 0; role = default; username = "";
        try
        {
            var claims = ReadValidatedClaims(token);
            if (claims == null) return false;
            using (claims)
            {
                var root = claims.RootElement;
                if (!int.TryParse(root.GetProperty("sub").GetString(), out userId) || userId <= 0) return false;
                if (!Enum.TryParse(root.GetProperty("role").GetString(), out role) || !Enum.IsDefined(role)) return false;
                username = root.GetProperty("username").GetString() ?? "";
                return true;
            }
        }
        catch { return false; }
    }

    public bool ValidateTokenForUser(string token, User user)
    {
        if (!user.IsActive || !ValidateToken(token, out var id, out var role, out _) || id != user.Id || role != user.Role) return false;
        try
        {
            using var claims = ReadValidatedClaims(token);
            var stamp = claims?.RootElement.GetProperty("stamp").GetString();
            return stamp != null && CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(stamp), Encoding.UTF8.GetBytes(Sign($"{user.PasswordHash}:{user.TokenVersion}")));
        }
        catch { return false; }
    }

    private JsonDocument? ReadValidatedClaims(string token)
    {
        if (string.IsNullOrWhiteSpace(token) || token.Length > 8192) return null;
        if (token.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)) token = token[7..].Trim();
        var parts = token.Split('.');
        if (parts.Length != 3) return null;
        if (!CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(parts[2]), Encoding.UTF8.GetBytes(Sign($"{parts[0]}.{parts[1]}")))) return null;
        using var header = JsonDocument.Parse(Decode(parts[0]));
        if (header.RootElement.GetProperty("alg").GetString() != "HS256") return null;
        var doc = JsonDocument.Parse(Decode(parts[1]));
        var root = doc.RootElement;
        if (!root.TryGetProperty("exp", out var expiry) || !expiry.TryGetInt64(out var seconds) ||
            DateTimeOffset.UtcNow.ToUnixTimeSeconds() >= seconds ||
            !root.TryGetProperty("iss", out var issuer) || issuer.GetString() != _issuer ||
            !root.TryGetProperty("aud", out var audience) || audience.GetString() != _audience ||
            !root.TryGetProperty("stamp", out _))
        { doc.Dispose(); return null; }
        return doc;
    }

    private string Sign(string input) => Encode(HMACSHA256.HashData(_keyBytes, Encoding.UTF8.GetBytes(input)));
    private static string Encode(byte[] data) => Convert.ToBase64String(data).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    private static byte[] Decode(string value) {
        var normalized = value.Replace('-', '+').Replace('_', '/');
        return Convert.FromBase64String(normalized.PadRight((normalized.Length + 3) / 4 * 4, '='));
    }
}
