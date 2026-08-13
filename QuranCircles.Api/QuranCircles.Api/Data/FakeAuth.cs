using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
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

    public static UserRole? GetRole(HttpContext ctx)
    {
        var token = GetToken(ctx);
        if (token != null)
        {
            var tokenSvc = ctx.RequestServices.GetRequiredService<TokenService>();
            if (tokenSvc.ValidateToken(token, out _, out var role, out _))
            {
                return role;
            }
        }

        var userIdHeader = ctx.Request.Headers["X-User-Id"].FirstOrDefault();
        if (int.TryParse(userIdHeader, out var userId))
        {
            var db = ctx.RequestServices.GetRequiredService<AppDbContext>();
            var user = db.Users.Find(userId);
            if (user != null) return user.Role;
        }

        return null;
    }

    public static int? GetUserId(HttpContext ctx)
    {
        var token = GetToken(ctx);
        if (token != null)
        {
            var tokenSvc = ctx.RequestServices.GetRequiredService<TokenService>();
            if (tokenSvc.ValidateToken(token, out var userId, out _, out _))
            {
                return userId;
            }
        }

        var userIdHeader = ctx.Request.Headers["X-User-Id"].FirstOrDefault();
        if (int.TryParse(userIdHeader, out var uid))
        {
            return uid;
        }

        return null;
    }
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
