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

        return null;
    }

    public static string? GetUsername(HttpContext ctx)
    {
        var token = GetToken(ctx);
        if (token != null)
        {
            var tokenSvc = ctx.RequestServices.GetRequiredService<TokenService>();
            if (tokenSvc.ValidateToken(token, out _, out _, out var username))
            {
                return username;
            }
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

        // Dynamic Role Resolution: Check dual role permissions (Teacher who is also Parent, Parent who is also Teacher)
        if (!isAllowed)
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
                        if (user.Role == UserRole.Admin || user.Role == UserRole.Developer)
                        {
                            isAllowed = true;
                        }
                        else if (_allowed.Contains(UserRole.Parent) && (user.Role == UserRole.Parent || user.ParentId.HasValue || user.TeacherId.HasValue))
                        {
                            isAllowed = true;
                        }
                        else if (_allowed.Contains(UserRole.Teacher) && (user.TeacherId.HasValue || user.Role == UserRole.Teacher))
                        {
                            isAllowed = true;
                        }
                        else if (_allowed.Contains(UserRole.Teacher))
                        {
                            var uName = (user.Username ?? "").Trim();
                            var isTch = db.Teachers.Any(t => (!string.IsNullOrEmpty(t.IdentityNumber) && t.IdentityNumber == uName) ||
                                                             (!string.IsNullOrEmpty(t.Contact) && t.Contact == uName) ||
                                                             (!string.IsNullOrEmpty(t.FullName) && t.FullName == user.FullName));
                            if (isTch) isAllowed = true;
                        }
                    }
                }
            }
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
