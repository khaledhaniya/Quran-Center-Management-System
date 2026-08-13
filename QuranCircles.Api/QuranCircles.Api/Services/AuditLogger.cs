using Microsoft.AspNetCore.Http;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using System;
using System.Threading.Tasks;

namespace QuranCircles.Api.Services;

public static class AuditLogger
{
    public static async Task LogAsync(AppDbContext db, HttpContext httpContext, string action, string details)
    {
        try
        {
            string username = "system";
            var userId = FakeAuth.GetUserId(httpContext);
            if (userId.HasValue)
            {
                var user = await db.Users.FindAsync(userId.Value);
                if (user != null)
                {
                    username = user.Username;
                }
            }

            var ip = httpContext.Connection.RemoteIpAddress?.ToString();
            if (string.IsNullOrEmpty(ip)) ip = "127.0.0.1";

            db.AuditLogs.Add(new AuditLog
            {
                Username = username,
                Action = action,
                Details = details,
                Timestamp = DateTime.UtcNow,
                IpAddress = ip
            });

            await db.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error logging audit event: {ex.Message}");
        }
    }
}
