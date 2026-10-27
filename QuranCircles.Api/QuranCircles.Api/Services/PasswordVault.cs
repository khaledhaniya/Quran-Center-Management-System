using System.Security.Cryptography;
using System.Text;

namespace QuranCircles.Api.Services;

// Allows the developer account to view passwords set after this feature was enabled.
// The key is derived from the server's persistent signing secret; never store it in the database.
public sealed class PasswordVault
{
    private readonly byte[] _key;

    public PasswordVault(TokenService tokens)
    {
        _key = tokens.DerivePurposeKey("password-vault-v1");
    }

    public string Protect(string password)
    {
        var nonce = RandomNumberGenerator.GetBytes(12);
        var plaintext = Encoding.UTF8.GetBytes(password);
        var ciphertext = new byte[plaintext.Length];
        var tag = new byte[16];
        using var aes = new AesGcm(_key, 16);
        aes.Encrypt(nonce, plaintext, ciphertext, tag);
        var packed = new byte[nonce.Length + tag.Length + ciphertext.Length];
        Buffer.BlockCopy(nonce, 0, packed, 0, nonce.Length);
        Buffer.BlockCopy(tag, 0, packed, nonce.Length, tag.Length);
        Buffer.BlockCopy(ciphertext, 0, packed, nonce.Length + tag.Length, ciphertext.Length);
        CryptographicOperations.ZeroMemory(plaintext);
        return Convert.ToBase64String(packed);
    }

    public string? Unprotect(string? protectedPassword)
    {
        if (string.IsNullOrWhiteSpace(protectedPassword)) return null;
        try
        {
            var packed = Convert.FromBase64String(protectedPassword);
            if (packed.Length < 28) return null;
            var plaintext = new byte[packed.Length - 28];
            using var aes = new AesGcm(_key, 16);
            aes.Decrypt(packed.AsSpan(0, 12), packed.AsSpan(28), packed.AsSpan(12, 16), plaintext);
            var result = Encoding.UTF8.GetString(plaintext);
            CryptographicOperations.ZeroMemory(plaintext);
            return result;
        }
        catch (CryptographicException) { return null; }
        catch (FormatException) { return null; }
    }
}
