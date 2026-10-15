using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using System;
using System.Linq;
using Microsoft.Extensions.DependencyInjection;

namespace QuranCircles.Api.Data;

public static class FakeAuth
{
    private static string? GetToken(HttpContext ctx)
    {
        var authHeader = ctx.Request.Headers["Authorization"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(authHeader)) return null;

        if (authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            return authHeader.Substring(7).Trim();
        }

        return authHeader.Trim();
    }

    private static User? VerifiedUser(HttpContext ctx)
    {
        const string cacheKey = "QuranCenter.VerifiedUser";
        if (ctx.Items.TryGetValue(cacheKey, out var cached)) return cached as User;
        ctx.Items[cacheKey] = null;
        var token = GetToken(ctx);
        if (token == null) return null;
        var tokens = ctx.RequestServices.GetRequiredService<TokenService>();
        if (!tokens.ValidateToken(token, out var id, out _, out _)) return null;
        var db = ctx.RequestServices.GetRequiredService<AppDbContext>();
        var user = db.Users.AsNoTracking().FirstOrDefault(u => u.Id == id);
        if (user == null || !tokens.ValidateTokenForUser(token, user)) return null;
        ctx.Items[cacheKey] = user;
        return user;
    }

    public static UserRole? GetRole(HttpContext ctx) => VerifiedUser(ctx)?.Role;
    public static int? GetUserId(HttpContext ctx) => VerifiedUser(ctx)?.Id;
    public static string? GetUsername(HttpContext ctx) => VerifiedUser(ctx)?.Username;

}

[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
public class RequireRoleAttribute : Attribute, IAuthorizationFilter
{
    private readonly UserRole[] _allowed;
    public RequireRoleAttribute(params UserRole[] allowed) => _allowed = allowed;

    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var role = FakeAuth.GetRole(context.HttpContext);

        if (role is null)
        {
            context.Result = new ObjectResult(new ProblemDetails
            {
                Title = "Missing or invalid token",
                Detail = "أرسل توكين توثيق صالح في ترويسة Authorization.",
                Status = StatusCodes.Status401Unauthorized
            })
            { StatusCode = StatusCodes.Status401Unauthorized };
            return;
        }

        bool isAllowed = _allowed.Contains(role.Value) ||
                          (role.Value == UserRole.Developer && _allowed.Contains(UserRole.Admin));

        // Dynamic Role Resolution: Check dual role permissions (Teacher who is also Parent, Parent who is also Teacher)
        if (!isAllowed)
        {
            try
            {
                var userId = FakeAuth.GetUserId(context.HttpContext);
                if (userId.HasValue)
                {
                    var db = context.HttpContext.RequestServices.GetService<AppDbContext>();
                    if (db != null)
                    {
                        var user = db.Users.Include(u => u.Teacher).FirstOrDefault(u => u.Id == userId.Value);
                        if (user != null)
                        {
                            if (_allowed.Contains(UserRole.Parent) && (user.Role == UserRole.Parent || (user.Role != UserRole.Student && (user.ParentId.HasValue || db.Students.Any(s => s.ParentId == user.Id)))))
                            {
                                isAllowed = true;
                            }
                            else if (_allowed.Contains(UserRole.Teacher) && user.Teacher?.IsActive == true)
                            {
                                isAllowed = true;
                            }

                        }
                    }
                }
            }
            catch { }
        }

        if (isAllowed && role.Value is not (UserRole.Admin or UserRole.Developer))
        {
            var db = context.HttpContext.RequestServices.GetRequiredService<AppDbContext>();
            var userId = FakeAuth.GetUserId(context.HttpContext);
            var task = db.Users.Include(u => u.Teacher).FirstOrDefault(u => u.Id == userId)?.Teacher;
            var path = context.HttpContext.Request.Path.Value?.ToLowerInvariant() ?? "";
            string[]? grants = path switch
            {
                var p when p.StartsWith("/api/quality") => ["الجودة"],
                var p when p.StartsWith("/api/finance") => ["الملف المالي"],
                var p when p.StartsWith("/api/talents") => ["الفتى الواعظ", "الأصوات الندية"],
                var p when p.StartsWith("/api/huffaz") => ["التحفيظ", "منتدى الحفاظ"],
                _ => null
            };
            if (grants != null)
                isAllowed = task?.IsActive == true && grants.Any(g => (task.TaskRole ?? "").Contains(g));
        }

        if (!isAllowed)
        {
            context.Result = new ObjectResult(new ProblemDetails
            {
                Title = "Access denied",
                Detail = "هذا الدور لا يملك صلاحية الوصول.",
                Status = StatusCodes.Status403Forbidden
            })
            { StatusCode = StatusCodes.Status403Forbidden };
        }
    }
}
