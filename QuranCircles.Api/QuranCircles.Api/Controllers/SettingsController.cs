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
            return Ok(new SystemSettings());
        }
    }

    [HttpPut]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> UpdateSettings([FromBody] UpdateSettingsDto dto)
    {
        try
        {
            var settings = await _db.SystemSettings.FirstOrDefaultAsync();
            if (settings == null)
            {
                settings = new SystemSettings();
                _db.SystemSettings.Add(settings);
            }

            // 1. Institutional Identity & Contact
            if (!string.IsNullOrWhiteSpace(dto.CenterName)) settings.CenterName = dto.CenterName.Trim();
            if (!string.IsNullOrWhiteSpace(dto.MosqueName)) settings.MosqueName = dto.MosqueName.Trim();
            if (!string.IsNullOrWhiteSpace(dto.CenterAddress)) settings.CenterAddress = dto.CenterAddress.Trim();
            if (!string.IsNullOrWhiteSpace(dto.SupportPhone)) settings.SupportPhone = dto.SupportPhone.Trim();
            if (!string.IsNullOrWhiteSpace(dto.SupportEmail)) settings.SupportEmail = dto.SupportEmail.Trim();
            if (!string.IsNullOrWhiteSpace(dto.WelcomeMessage)) settings.WelcomeMessage = dto.WelcomeMessage.Trim();
            if (!string.IsNullOrWhiteSpace(dto.LogoUrl)) settings.LogoUrl = dto.LogoUrl.Trim();
            if (!string.IsNullOrWhiteSpace(dto.ThemeStyle)) settings.ThemeStyle = dto.ThemeStyle.Trim();

            // 2. Academic & Quranic Standards
            if (dto.PassingScoreThreshold.HasValue && dto.PassingScoreThreshold.Value > 0)
                settings.PassingScoreThreshold = dto.PassingScoreThreshold.Value;

            if (dto.MinAttendancePercentForExam.HasValue && dto.MinAttendancePercentForExam.Value > 0)
                settings.MinAttendancePercentForExam = dto.MinAttendancePercentForExam.Value;

            if (dto.MaxStudentsPerCircle.HasValue && dto.MaxStudentsPerCircle.Value > 0)
                settings.MaxStudentsPerCircle = dto.MaxStudentsPerCircle.Value;

            if (dto.MaxAbsenceDaysWarning.HasValue && dto.MaxAbsenceDaysWarning.Value > 0)
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
            if (!string.IsNullOrWhiteSpace(dto.SignatoryName)) settings.SignatoryName = dto.SignatoryName.Trim();
            if (!string.IsNullOrWhiteSpace(dto.SignatoryTitle)) settings.SignatoryTitle = dto.SignatoryTitle.Trim();
            if (dto.ShowHonorsBoard.HasValue) settings.ShowHonorsBoard = dto.ShowHonorsBoard.Value;

            // 5. Alerts & Communication
            if (dto.AllowPublicAnnouncements.HasValue) settings.AllowPublicAnnouncements = dto.AllowPublicAnnouncements.Value;
            if (dto.EnableAbsenceAutoAlert.HasValue) settings.EnableAbsenceAutoAlert = dto.EnableAbsenceAutoAlert.Value;
            if (!string.IsNullOrWhiteSpace(dto.AbsenceAlertTemplate)) settings.AbsenceAlertTemplate = dto.AbsenceAlertTemplate.Trim();

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
            return File(bytes, "application/json", $"quran_center_backup_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json");
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "فشل تصدير النسخة الاحتياطية: " + ex.Message });
        }
    }

    [HttpPost("restore")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> RestoreBackup([FromBody] System.Text.Json.JsonElement payload)
    {
        try
        {
            if (payload.TryGetProperty("Students", out var studentsEl) && studentsEl.ValueKind == System.Text.Json.JsonValueKind.Array)
            {
                var students = System.Text.Json.JsonSerializer.Deserialize<List<Student>>(studentsEl.GetRawText());
                if (students != null && students.Any())
                {
                    foreach (var s in students)
                    {
                        var existing = await _db.Students.FindAsync(s.Id);
                        if (existing != null) _db.Entry(existing).CurrentValues.SetValues(s);
                        else _db.Students.Add(s);
                    }
                }
            }

            if (payload.TryGetProperty("Teachers", out var teachersEl) && teachersEl.ValueKind == System.Text.Json.JsonValueKind.Array)
            {
                var teachers = System.Text.Json.JsonSerializer.Deserialize<List<Teacher>>(teachersEl.GetRawText());
                if (teachers != null && teachers.Any())
                {
                    foreach (var t in teachers)
                    {
                        var existing = await _db.Teachers.FindAsync(t.Id);
                        if (existing != null) _db.Entry(existing).CurrentValues.SetValues(t);
                        else _db.Teachers.Add(t);
                    }
                }
            }

            if (payload.TryGetProperty("Circles", out var circlesEl) && circlesEl.ValueKind == System.Text.Json.JsonValueKind.Array)
            {
                var circles = System.Text.Json.JsonSerializer.Deserialize<List<Circle>>(circlesEl.GetRawText());
                if (circles != null && circles.Any())
                {
                    foreach (var c in circles)
                    {
                        var existing = await _db.Circles.FindAsync(c.Id);
                        if (existing != null) _db.Entry(existing).CurrentValues.SetValues(c);
                        else _db.Circles.Add(c);
                    }
                }
            }

            if (payload.TryGetProperty("ProfileUpdateRequests", out var reqsEl) && reqsEl.ValueKind == System.Text.Json.JsonValueKind.Array)
            {
                var reqs = System.Text.Json.JsonSerializer.Deserialize<List<ProfileUpdateRequest>>(reqsEl.GetRawText());
                if (reqs != null && reqs.Any())
                {
                    foreach (var r in reqs)
                    {
                        var existing = await _db.ProfileUpdateRequests.FindAsync(r.Id);
                        if (existing != null) _db.Entry(existing).CurrentValues.SetValues(r);
                        else _db.ProfileUpdateRequests.Add(r);
                    }
                }
            }

            await _db.SaveChangesAsync();
            return Ok(new { message = "تم استعادة كافة بيانات المنظومة بنجاح تام." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "فشل استعادة البيانات: " + ex.Message });
        }
    }
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
    bool? MaintenanceMode
);
