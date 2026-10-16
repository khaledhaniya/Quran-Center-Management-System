using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Extensions.Caching.Memory;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace QuranCircles.Api.Services;

public static class CertificateArtifacts
{
    // Access is checked by ExportsController on every ticket request, before using this cache.
    // The full certificate content is the cache key, so edits invalidate the cached artifact.
    private static readonly MemoryCache Cache = new(new MemoryCacheOptions { SizeLimit = 24 * 1024 * 1024 });

    public static byte[] Render(CertificateData data, string format, bool thumbnail = false)
    {
        if (format is not ("pdf" or "png")) throw new ArgumentException("Unsupported certificate format", nameof(format));
        var key = Convert.ToHexString(SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(data))) + $":{format}:{thumbnail}";
        if (Cache.TryGetValue(key, out byte[]? cached) && cached != null) return cached;

        var document = DocumentRenderer.Certificate(data);
        var bytes = format == "pdf" ? document.GeneratePdf()
            : document.GenerateImages(new ImageGenerationSettings { RasterDpi = thumbnail ? 72 : 144 }).Single();
        Cache.Set(key, bytes, new MemoryCacheEntryOptions {
            Size = bytes.Length,
            AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10)
        });
        return bytes;
    }
}
