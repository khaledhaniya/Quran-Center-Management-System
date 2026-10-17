using QuranCircles.Api.Data;

namespace QuranCircles.Api.Services;

public static class WebRequestPolicy
{
    public static bool IsPrivateFile(string path)
    {
        var segments = path.Replace('\\', '/').Split('/', StringSplitOptions.RemoveEmptyEntries);
        return segments.Any(s => s.Equals("App_Data", StringComparison.OrdinalIgnoreCase) || (s.StartsWith('.') && s != ".well-known") ||
            s.StartsWith("appsettings", StringComparison.OrdinalIgnoreCase) || s.Equals("web.config", StringComparison.OrdinalIgnoreCase) ||
            s.EndsWith(".db", StringComparison.OrdinalIgnoreCase) || s.EndsWith(".db-wal", StringComparison.OrdinalIgnoreCase) ||
            s.EndsWith(".db-shm", StringComparison.OrdinalIgnoreCase) || s.EndsWith(".bak", StringComparison.OrdinalIgnoreCase) ||
            s.EndsWith(".log", StringComparison.OrdinalIgnoreCase) || s.EndsWith(".cs", StringComparison.OrdinalIgnoreCase) ||
            s.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase) || s.Equals("signing-key.bin", StringComparison.OrdinalIgnoreCase));
    }

    public static bool IsPublicApi(HttpRequest request) =>
        (request.Path.Equals("/api/auth/login", StringComparison.OrdinalIgnoreCase) && HttpMethods.IsPost(request.Method)) ||
        ((request.Path.Equals("/api/settings", StringComparison.OrdinalIgnoreCase) || request.Path.Equals("/api/status", StringComparison.OrdinalIgnoreCase)) && HttpMethods.IsGet(request.Method)) ||
        (request.Path.StartsWithSegments("/api/exports/files", StringComparison.OrdinalIgnoreCase) && HttpMethods.IsGet(request.Method));

    public static Task Apply(HttpContext context, RequestDelegate next)
    {
        var headers = context.Response.Headers;
        headers.XContentTypeOptions = "nosniff";
        headers.XFrameOptions = "SAMEORIGIN";
        headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
        headers["Content-Security-Policy"] = "base-uri 'self'; object-src 'none'; frame-ancestors 'self'; form-action 'self'";
        headers["Permissions-Policy"] = "camera=(self), microphone=(self), geolocation=()";
        if (context.Request.IsHttps) headers.StrictTransportSecurity = "max-age=31536000";
        if (IsPrivateFile(context.Request.Path.Value ?? "")) { context.Response.StatusCode = 404; return Task.CompletedTask; }
        if (context.Request.Path.StartsWithSegments("/api", StringComparison.OrdinalIgnoreCase))
        {
            headers.CacheControl = "no-store, private";
            if (!HttpMethods.IsOptions(context.Request.Method) && !IsPublicApi(context.Request) && FakeAuth.GetRole(context) == null)
            {
                context.Response.StatusCode = 401;
                return context.Response.WriteAsJsonAsync(new { error = "يرجى تسجيل الدخول للوصول إلى هذه البيانات." });
            }
        }
        return next(context);
    }

    public static string StaticCache(HttpRequest request)
    {
        var extension = Path.GetExtension(request.Path.Value ?? "").ToLowerInvariant();
        if (!request.Path.StartsWithSegments("/uploads", StringComparison.OrdinalIgnoreCase) &&
            new[] { ".js", ".mjs", ".css", ".png", ".jpg", ".jpeg", ".svg", ".webp", ".gif", ".woff", ".woff2", ".ttf", ".otf", ".wasm" }.Contains(extension))
            return request.Query.ContainsKey("v") ? "public, max-age=31536000, immutable" : "public, max-age=86400";
        return "no-cache, max-age=0, must-revalidate";
    }
}
