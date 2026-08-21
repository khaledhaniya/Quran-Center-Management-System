using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using System;
using System.Threading.Tasks;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SettingsController : ControllerBase
{
    private readonly AppDbContext _db;

    public SettingsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetSettings()
    {
        var settings = await _db.SystemSettings.FirstOrDefaultAsync();
        if (settings == null)
        {
            settings = new SystemSettings();
            _db.SystemSettings.Add(settings);
            await _db.SaveChangesAsync();
        }
        return Ok(settings);
    }

    [HttpPut]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> UpdateSettings([FromBody] UpdateSettingsDto dto)
    {
        var settings = await _db.SystemSettings.FirstOrDefaultAsync();
        if (settings == null)
        {
            settings = new SystemSettings();
            _db.SystemSettings.Add(settings);
        }

        if (!string.IsNullOrWhiteSpace(dto.CenterName)) settings.CenterName = dto.CenterName.Trim();
        if (!string.IsNullOrWhiteSpace(dto.MosqueName)) settings.MosqueName = dto.MosqueName.Trim();
        if (!string.IsNullOrWhiteSpace(dto.SupportPhone)) settings.SupportPhone = dto.SupportPhone.Trim();
        if (!string.IsNullOrWhiteSpace(dto.WelcomeMessage)) settings.WelcomeMessage = dto.WelcomeMessage.Trim();
        if (!string.IsNullOrWhiteSpace(dto.ThemeStyle)) settings.ThemeStyle = dto.ThemeStyle.Trim();

        settings.ShowStudentCountToTeacher = dto.ShowStudentCountToTeacher;
        settings.ShowCumulativeAttendance = dto.ShowCumulativeAttendance;
        settings.AllowTeacherSelfEnrollment = dto.AllowTeacherSelfEnrollment;
        settings.AllowPublicAnnouncements = dto.AllowPublicAnnouncements;
        settings.EnableCertificates = dto.EnableCertificates;
        settings.UpdatedAt = DateTime.UtcNow;

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        _db.AuditLogs.Add(new AuditLog
        {
            Username = currentUser?.Username ?? "Unknown",
            Action = "UpdateSystemSettings",
            Details = $"تحديث إعدادات النظام ولوحة التحكم الديناميكية بواسطة {currentUser?.FullName}",
            Timestamp = DateTime.UtcNow,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
        });

        await _db.SaveChangesAsync();
        return Ok(new { Message = "تم حفظ وتطبيق إعدادات النظام بنجاح.", Settings = settings });
    }
}

public record UpdateSettingsDto(
    string? CenterName,
    string? MosqueName,
    bool ShowStudentCountToTeacher,
    bool ShowCumulativeAttendance,
    bool AllowTeacherSelfEnrollment,
    bool AllowPublicAnnouncements,
    bool EnableCertificates,
    string? SupportPhone,
    string? WelcomeMessage,
    string? ThemeStyle
);
