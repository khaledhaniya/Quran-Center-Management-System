using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using System.Collections.Concurrent;
using System.Security.Cryptography;

namespace QuranCircles.Api.Controllers;

[ApiController, Route("api/exports")]
public class ExportsController(AppDbContext db) : ControllerBase
{
    private record Ticket(int UserId, byte[] Bytes, string Type, string Name, DateTime Expires);
    private static readonly ConcurrentDictionary<string, Ticket> Tickets = new();
    public record ExportRequest(ReportFilter? Filter, string Format = "pdf", string? CertificateKind = null, int? CertificateId = null, bool Thumbnail = false);

    [HttpGet("catalog")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public IActionResult Catalog() => Ok(OperationalReports.Catalog);

    [HttpPost("preview")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Preview(ReportFilter filter)
    {
        try { return Ok(await new OperationalReports(db).BuildAsync(filter)); }
        catch (ArgumentException ex) { return BadRequest(new { error = ex.Message }); }
    }

    [HttpPost("ticket")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.Student, UserRole.Parent, UserRole.ExamSupervisor)]
    public async Task<IActionResult> CreateTicket(ExportRequest request)
    {
        if (!new[] { "pdf", "xlsx", "png" }.Contains(request.Format)) return BadRequest();
        var userId = FakeAuth.GetUserId(HttpContext)!.Value;
        var user = await db.Users.Include(u => u.Teacher).SingleAsync(u => u.Id == userId);
        byte[] bytes; string name; string type;
        if (request.CertificateId.HasValue)
        {
            var settings = await db.SystemSettings.AsNoTracking().FirstOrDefaultAsync() ?? new SystemSettings();
            if (!settings.EnableCertificates) return BadRequest(new { error = "إصدار الشهادات معطل." });
            CertificateData data; int studentId; int? teacherId;
            string instructorTitle;
            if (request.CertificateKind == "course")
            {
                var item = await db.CourseEnrollments.Include(e => e.Student).Include(e => e.Course).FirstOrDefaultAsync(e => e.Id == request.CertificateId);
                if (item == null || string.IsNullOrWhiteSpace(item.CertificateCode) ||
                    item.Status is not ("Passed" or "Certified") ||
                    !item.Grade.HasValue || item.Grade.Value < settings.PassingScoreThreshold) return NotFound();
                studentId = item.StudentId; teacherId = item.Course?.TeacherId;
                instructorTitle = "معلم الدورة";
                data = new CertificateData(settings.CenterName ?? "", item.Student!.FullName, item.Course!.Name, item.CertificateCode,
                    item.CertificateDate?.ToString("yyyy-MM-dd") ?? "", item.Grade?.ToString("0.##") ?? "ناجح", settings.SignatoryName ?? "إدارة المركز");
            }
            else if (request.CertificateKind == "exam")
            {
                var item = await db.ExamNominations.Include(e => e.Student).ThenInclude(s => s!.Circle)
                    .Include(e => e.Result).Include(e => e.Course).FirstOrDefaultAsync(e => e.Id == request.CertificateId);
                if (item?.Result == null || item.Status != "Completed" || item.Result.Grade < settings.PassingScoreThreshold) return NotFound();
                studentId = item.StudentId;
                instructorTitle = item.NominationType == "Course" ? "معلم الدورة" : "معلم القرآن";
                teacherId = item.NominationType == "Course"
                    ? item.Course?.TeacherId ?? item.TeacherId
                    : item.Student?.Circle?.TeacherId ?? item.TeacherId;
                var achievement = item.NominationType == "Combined"
                    ? $"اختبار السلاسل المجتمعة • الأجزاء {item.JuzStart} إلى {item.JuzEnd}"
                    : $"اختبار القرآن الكريم • الأجزاء {item.JuzStart} إلى {item.JuzEnd}";
                data = new CertificateData(settings.CenterName ?? "", item.Student!.FullName, item.Course?.Name ?? achievement, $"EXAM-{item.Id}",
                    item.ExamDate?.ToString("yyyy-MM-dd") ?? "", item.Result.Grade.ToString("0.##"), settings.SignatoryName ?? "إدارة المركز");
            }
            else return BadRequest();
            var assignedTeacher = teacherId.HasValue
                ? await db.Teachers.AsNoTracking().FirstOrDefaultAsync(t => t.Id == teacherId.Value)
                : null;
            var centerLeaders = await db.Teachers.AsNoTracking()
                .Where(t => t.IsActive && t.TaskRole != null).ToListAsync();
            var centerLeader = centerLeaders.FirstOrDefault(t => t.TaskRole!.Contains("أمير المركز"))
                ?? centerLeaders.FirstOrDefault(t => t.TaskRole!.Split('+', ',').Any(r => r.Trim() == "مركز البيان"));
            var configuredSignatory = settings.SignatoryName?.Trim();
            var hasNamedSignatory = !string.IsNullOrWhiteSpace(configuredSignatory) &&
                configuredSignatory != "فضيلة الشيخ / رئيس المركز" && configuredSignatory != "إدارة المركز";
            data = data with {
                Signatory = hasNamedSignatory ? configuredSignatory! : centerLeader?.FullName ?? "إدارة المركز",
                Instructor = assignedTeacher?.FullName ?? "",
                InstructorTitle = instructorTitle
            };
            var student = await db.Students.FindAsync(studentId);
            var circleTeacherAccess = user.TeacherId.HasValue && student?.CircleId.HasValue == true &&
                await db.Circles.AnyAsync(c => c.Id == student.CircleId.Value && c.TeacherId == user.TeacherId.Value);
            bool access = user.Role is UserRole.Admin or UserRole.Developer || user.StudentId == studentId ||
                (user.TeacherId.HasValue && user.TeacherId == teacherId) || circleTeacherAccess ||
                (student != null && ParentLinks.IsChild(user, student));
            if (!access) return Forbid();
            if (request.Format == "xlsx") return BadRequest();
            bytes = CertificateArtifacts.Render(data, request.Format, request.Thumbnail);
            name = $"certificate-{request.CertificateKind}-{request.CertificateId}.{request.Format}";
        }
        else
        {
            var filter = request.Filter ?? new ReportFilter();
            if (user.Role is not (UserRole.Admin or UserRole.Developer) &&
                !(filter.Kind == "finance" && user.Teacher?.IsActive == true && (user.Teacher.TaskRole ?? "").Contains("الملف المالي"))) return Forbid();
            if (request.Format == "png") return BadRequest();
            ReportTable report;
            try { report = await new OperationalReports(db).BuildAsync(filter); }
            catch (ArgumentException ex) { return BadRequest(new { error = ex.Message }); }
            bytes = request.Format == "xlsx" ? DocumentRenderer.Excel(report) : DocumentRenderer.Pdf(report);
            name = $"{filter.Kind}-{CenterClock.Today:yyyy-MM-dd}.{request.Format}";
        }
        type = request.Format == "xlsx" ? "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" : request.Format == "png" ? "image/png" : "application/pdf";
        foreach (var old in Tickets.Where(x => x.Value.Expires < DateTime.UtcNow).ToList()) Tickets.TryRemove(old.Key, out _);
        if (Tickets.Count > 100) return StatusCode(429, new { error = "يرجى إعادة محاولة التنزيل بعد قليل." });
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        Tickets[token] = new Ticket(userId, bytes, type, name, DateTime.UtcNow.AddMinutes(2));
        return Ok(new { url = $"/api/exports/files/{token}", fileName = name, expiresInSeconds = 120 });
    }

    [HttpGet("files/{token}")]
    public async Task<IActionResult> FileByTicket(string token)
    {
        if (!Tickets.TryRemove(token, out var ticket) || ticket.Expires < DateTime.UtcNow) return NotFound();
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == ticket.UserId && u.IsActive);
        if (user == null) return Unauthorized();
        if (user.Role != UserRole.Developer && await db.SystemSettings.AnyAsync(s => s.MaintenanceMode)) return StatusCode(503);
        Response.Headers.CacheControl = "no-store";
        Response.Headers["Referrer-Policy"] = "no-referrer";
        return File(ticket.Bytes, ticket.Type, ticket.Name);
    }
}
