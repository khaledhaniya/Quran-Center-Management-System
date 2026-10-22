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
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> GetSettings()
    {
        try
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
        catch (Exception)
        {
            return StatusCode(503, new { error = "تعذر تحميل إعدادات المركز من قاعدة البيانات." });
        }
    }

    [HttpPut]
    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> UpdateSettings([FromBody] UpdateSettingsDto dto)
    {
        if (dto.PassingScoreThreshold is < 50 or > 100 ||
            dto.MinAttendancePercentForExam is < 0 or > 100 ||
            dto.MaxStudentsPerCircle is < 5 or > 50 ||
            dto.MaxAbsenceDaysWarning is < 1 or > 15)
            return BadRequest(new { error = "قيمة أحد المعايير خارج النطاق المسموح." });
        if (dto.ThemeStyle != null && dto.ThemeStyle is not ("Classic" or "Modern" or "Sapphire" or "Dark"))
            return BadRequest(new { error = "نمط المظهر غير معروف." });
        if (dto.MaintenanceMode.HasValue && FakeAuth.GetRole(HttpContext) != UserRole.Developer)
            return Forbid();
        try
        {
            var settings = await _db.SystemSettings.FirstOrDefaultAsync();
            if (settings == null)
            {
                settings = new SystemSettings();
                _db.SystemSettings.Add(settings);
            }

            // 1. Institutional Identity & Contact
            if (dto.CenterName != null) settings.CenterName = dto.CenterName.Trim();
            if (dto.MosqueName != null) settings.MosqueName = dto.MosqueName.Trim();
            if (dto.CenterAddress != null) settings.CenterAddress = dto.CenterAddress.Trim();
            if (dto.SupportPhone != null) settings.SupportPhone = dto.SupportPhone.Trim();
            if (dto.SupportEmail != null) settings.SupportEmail = dto.SupportEmail.Trim();
            if (dto.WelcomeMessage != null) settings.WelcomeMessage = dto.WelcomeMessage.Trim();
            if (dto.LogoUrl != null) settings.LogoUrl = dto.LogoUrl.Trim();
            if (dto.ThemeStyle != null) settings.ThemeStyle = dto.ThemeStyle.Trim();

            // 2. Academic & Quranic Standards
            if (dto.PassingScoreThreshold.HasValue)
                settings.PassingScoreThreshold = dto.PassingScoreThreshold.Value;

            if (dto.MinAttendancePercentForExam.HasValue)
                settings.MinAttendancePercentForExam = dto.MinAttendancePercentForExam.Value;

            if (dto.MaxStudentsPerCircle.HasValue)
                settings.MaxStudentsPerCircle = dto.MaxStudentsPerCircle.Value;

            if (dto.MaxAbsenceDaysWarning.HasValue)
                settings.MaxAbsenceDaysWarning = dto.MaxAbsenceDaysWarning.Value;

            // 3. Security, Permissions & Access Control
            if (dto.AllowTeacherEditStudentPlan.HasValue) settings.AllowTeacherEditStudentPlan = dto.AllowTeacherEditStudentPlan.Value;
            if (dto.AllowTeacherSelfEnrollment.HasValue) settings.AllowTeacherSelfEnrollment = dto.AllowTeacherSelfEnrollment.Value;
            if (dto.HideParentPhoneFromTeacher.HasValue) settings.HideParentPhoneFromTeacher = dto.HideParentPhoneFromTeacher.Value;
            if (dto.AllowStudentProfileEditRequests.HasValue) settings.AllowStudentProfileEditRequests = dto.AllowStudentProfileEditRequests.Value;
            if (dto.EnforceDailyAttendanceRecording.HasValue) settings.EnforceDailyAttendanceRecording = dto.EnforceDailyAttendanceRecording.Value;
            if (dto.ShowStudentCountToTeacher.HasValue) settings.ShowStudentCountToTeacher = dto.ShowStudentCountToTeacher.Value;
            if (dto.ShowCumulativeAttendance.HasValue) settings.ShowCumulativeAttendance = dto.ShowCumulativeAttendance.Value;

            // 4. Certificates & Recognition
            if (dto.EnableCertificates.HasValue) settings.EnableCertificates = dto.EnableCertificates.Value;
            if (dto.SignatoryName != null) settings.SignatoryName = dto.SignatoryName.Trim();
            if (dto.SignatoryTitle != null) settings.SignatoryTitle = dto.SignatoryTitle.Trim();
            if (dto.ShowHonorsBoard.HasValue) settings.ShowHonorsBoard = dto.ShowHonorsBoard.Value;

            // 5. Alerts & Communication
            if (dto.AllowPublicAnnouncements.HasValue) settings.AllowPublicAnnouncements = dto.AllowPublicAnnouncements.Value;
            if (dto.EnableAbsenceAutoAlert.HasValue) settings.EnableAbsenceAutoAlert = dto.EnableAbsenceAutoAlert.Value;
            if (dto.AbsenceAlertTemplate != null) settings.AbsenceAlertTemplate = dto.AbsenceAlertTemplate.Trim();
            if (dto.EnableRecitationIncompleteAlert.HasValue) settings.EnableRecitationIncompleteAlert = dto.EnableRecitationIncompleteAlert.Value;
            if (dto.RecitationAlertTemplate != null) settings.RecitationAlertTemplate = dto.RecitationAlertTemplate.Trim();

            // 6. UI & Appearance
            if (dto.MaintenanceMode.HasValue) settings.MaintenanceMode = dto.MaintenanceMode.Value;

            settings.UpdatedAt = DateTime.UtcNow;

            var currentUserId = FakeAuth.GetUserId(HttpContext);
            var currentUser = await _db.Users.FindAsync(currentUserId);
            _db.AuditLogs.Add(new AuditLog
            {
                Username = currentUser?.Username ?? "Admin",
                Action = "UpdateSystemSettings",
                Details = $"تحديث إعدادات المنظومة الشاملة CMS بواسطة {currentUser?.FullName ?? "مدير النظام"}",
                Timestamp = DateTime.UtcNow,
                IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
            });

            await _db.SaveChangesAsync();
            return Ok(settings);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "فشل حفظ الإعدادات: " + ex.Message });
        }
    }

    [HttpGet("backup")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> ExportBackup()
    {
        try
        {
            var data = new
            {
                ExportDate = DateTime.UtcNow,
                Version = "2.0",
                Settings = await _db.SystemSettings.FirstOrDefaultAsync(),
                Users = await _db.Users.ToListAsync(),
                Teachers = await _db.Teachers.ToListAsync(),
                Circles = await _db.Circles.ToListAsync(),
                Students = await _db.Students.ToListAsync(),
                Sessions = await _db.Sessions.ToListAsync(),
                Attendances = await _db.Attendances.ToListAsync(),
                Announcements = await _db.Announcements.ToListAsync(),
                Courses = await _db.Courses.ToListAsync(),
                CourseEnrollments = await _db.CourseEnrollments.ToListAsync(),
                CourseAttendances = await _db.CourseAttendances.ToListAsync(),
                HadithSessions = await _db.HadithSessions.ToListAsync(),
                ExamNominations = await _db.ExamNominations.ToListAsync(),
                ExamResults = await _db.ExamResults.ToListAsync(),
                ProfileUpdateRequests = await _db.ProfileUpdateRequests.ToListAsync(),
                AuditLogs = await _db.AuditLogs.Take(500).ToListAsync()
            };

            var json = System.Text.Json.JsonSerializer.Serialize(data, new System.Text.Json.JsonSerializerOptions
            {
                WriteIndented = true
            });

            var bytes = System.Text.Encoding.UTF8.GetBytes(json);
            return File(bytes, "application/json", $"quran_center_data_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json");
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "فشل تصدير النسخة الاحتياطية: " + ex.Message });
        }
    }

    [HttpPost("restore")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public IActionResult RestoreBackup() => StatusCode(410, new
    {
        error = "تم إيقاف الاستعادة الجزئية لأنها لا تعيد قاعدة البيانات كاملة. استخدم نسخة SQL من لوحة الاستضافة."
    });
}

public record UpdateSettingsDto(
    string? CenterName,
    string? MosqueName,
    string? CenterAddress,
    string? SupportPhone,
    string? SupportEmail,
    string? WelcomeMessage,
    string? LogoUrl,
    string? ThemeStyle,
    int? PassingScoreThreshold,
    int? MinAttendancePercentForExam,
    int? MaxStudentsPerCircle,
    int? MaxAbsenceDaysWarning,
    bool? AllowTeacherEditStudentPlan,
    bool? AllowTeacherSelfEnrollment,
    bool? HideParentPhoneFromTeacher,
    bool? AllowStudentProfileEditRequests,
    bool? EnforceDailyAttendanceRecording,
    bool? ShowStudentCountToTeacher,
    bool? ShowCumulativeAttendance,
    bool? EnableCertificates,
    string? SignatoryName,
    string? SignatoryTitle,
    bool? ShowHonorsBoard,
    bool? AllowPublicAnnouncements,
    bool? EnableAbsenceAutoAlert,
    string? AbsenceAlertTemplate,
    bool? EnableRecitationIncompleteAlert,
    string? RecitationAlertTemplate,
    bool? MaintenanceMode
);
