namespace QuranCircles.Api.Controllers;

using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

[ApiController]
[Route("api/sms")]
public class SmsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly SmsGateway _gateway;

    public SmsController(AppDbContext db, SmsGateway gateway)
    {
        _db = db;
        _gateway = gateway;
    }

    public record SendSmsDto(
        int TargetType, // 1: All Center, 2: Circle, 3: Teacher, 4: Student, 5: All Teachers, 6: Admin/Dev
        int? TargetId,
        string MessageContent
    );

    [HttpPost("send")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.ExamSupervisor)]
    public async Task<IActionResult> SendSms([FromBody] SendSmsDto dto)
    {
        if (!_gateway.IsConfigured)
            return StatusCode(503, new { error = "خدمة SMS غير مهيأة. لم يتم إرسال أي رسالة؛ يرجى إعداد بوابة الرسائل أولاً." });
        if (string.IsNullOrWhiteSpace(dto.MessageContent))
        {
            return BadRequest(new { error = "محتوى نص رسالة SMS مطلوب." });
        }

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        if (!currentUserId.HasValue) return Unauthorized();

        var currentUser = await _db.Users.FindAsync(currentUserId.Value);
        if (currentUser == null) return Unauthorized();

        var recipients = new List<string>();
        string targetDescription = "الجميع بالمركز";

        if (currentUser.Role == UserRole.ExamSupervisor)
        {
            // Supervisor can only send to Admin/Dev or Student scheduled for exam
            if (dto.TargetType == 4 && dto.TargetId.HasValue)
            {
                var s = await _db.Students.FindAsync(dto.TargetId.Value);
                if (s != null)
                {
                    if (!string.IsNullOrEmpty(s.StudentMobile)) recipients.Add(s.StudentMobile);
                    if (!string.IsNullOrEmpty(s.FamilyContact)) recipients.Add(s.FamilyContact);
                    targetDescription = $"الطالب والمرشح للاختبار: {s.FullName}";
                }
            }
            else
            {
                // Default to Admins/Developers
                var admins = await _db.Users
                    .Where(u => u.Role == UserRole.Admin || u.Role == UserRole.Developer)
                    .ToListAsync();
                targetDescription = "إدارة المركز والمطورين";
            }
        }
        else if (currentUser.Role == UserRole.Teacher)
        {
            int teacherId = currentUser.TeacherId ?? 0;
            if (dto.TargetType == 2 && dto.TargetId.HasValue)
            {
                var circle = await _db.Circles.FindAsync(dto.TargetId.Value);
                if (circle == null || (circle.TeacherId != teacherId && circle.AssistantTeacherId != teacherId))
                    return StatusCode(403, new { error = "غير مسموح بالإرسال إلى حلقة خارج إشرافك." });
                var students = await _db.Students.Where(s => s.CircleId == dto.TargetId.Value).ToListAsync();
                foreach (var s in students)
                {
                    if (!string.IsNullOrEmpty(s.StudentMobile)) recipients.Add(s.StudentMobile);
                    if (!string.IsNullOrEmpty(s.FamilyContact)) recipients.Add(s.FamilyContact);
                }
                targetDescription = $"طلاب حلقة: {circle?.Name}";
            }
            else if (dto.TargetType == 4 && dto.TargetId.HasValue)
            {
                var s = await _db.Students.FindAsync(dto.TargetId.Value);
                if (s == null || !await _db.Circles.AnyAsync(c => c.Id == s.CircleId && (c.TeacherId == teacherId || c.AssistantTeacherId == teacherId)))
                    return StatusCode(403, new { error = "غير مسموح بالإرسال إلى طالب خارج حلقتك." });
                if (s != null)
                {
                    if (!string.IsNullOrEmpty(s.StudentMobile)) recipients.Add(s.StudentMobile);
                    if (!string.IsNullOrEmpty(s.FamilyContact)) recipients.Add(s.FamilyContact);
                    targetDescription = $"الطالب: {s.FullName}";
                }
            }
        }
        else
        {
            // Admin & Developer
            switch (dto.TargetType)
            {
                case 1: // All Center
                    var allStudents = await _db.Students.ToListAsync();
                    var allTeachers = await _db.Teachers.ToListAsync();
                    foreach (var s in allStudents)
                    {
                        if (!string.IsNullOrEmpty(s.StudentMobile)) recipients.Add(s.StudentMobile);
                        if (!string.IsNullOrEmpty(s.FamilyContact)) recipients.Add(s.FamilyContact);
                    }
                    foreach (var t in allTeachers)
                    {
                        if (!string.IsNullOrEmpty(t.Contact)) recipients.Add(t.Contact);
                    }
                    targetDescription = "كافة منتسبي المركز (طلاب ومعلمين)";
                    break;
                case 2: // Specific Circle
                    if (dto.TargetId.HasValue)
                    {
                        var circle = await _db.Circles.FindAsync(dto.TargetId.Value);
                        var cStudents = await _db.Students.Where(s => s.CircleId == dto.TargetId.Value).ToListAsync();
                        foreach (var s in cStudents)
                        {
                            if (!string.IsNullOrEmpty(s.StudentMobile)) recipients.Add(s.StudentMobile);
                            if (!string.IsNullOrEmpty(s.FamilyContact)) recipients.Add(s.FamilyContact);
                        }
                        targetDescription = $"طلاب حلقة: {circle?.Name}";
                    }
                    break;
                case 3: // Specific Teacher
                    if (dto.TargetId.HasValue)
                    {
                        var t = await _db.Teachers.FindAsync(dto.TargetId.Value);
                        if (t != null && !string.IsNullOrEmpty(t.Contact)) recipients.Add(t.Contact);
                        targetDescription = $"المعلم: {t?.FullName}";
                    }
                    break;
                case 4: // Specific Student
                    if (dto.TargetId.HasValue)
                    {
                        var s = await _db.Students.FindAsync(dto.TargetId.Value);
                        if (s != null)
                        {
                            if (!string.IsNullOrEmpty(s.StudentMobile)) recipients.Add(s.StudentMobile);
                            if (!string.IsNullOrEmpty(s.FamilyContact)) recipients.Add(s.FamilyContact);
                            targetDescription = $"الطالب: {s.FullName}";
                        }
                    }
                    break;
                case 5: // All Teachers
                    var teachers = await _db.Teachers.ToListAsync();
                    foreach (var t in teachers)
                    {
                        if (!string.IsNullOrEmpty(t.Contact)) recipients.Add(t.Contact);
                    }
                    targetDescription = "جميع المعلمين والمحفظين";
                    break;
            }
        }

        recipients = recipients.Where(r => !string.IsNullOrWhiteSpace(r)).Distinct().ToList();

        if (recipients.Count == 0) return BadRequest(new { error = "لا توجد أرقام صالحة للمستلمين المحددين." });
        try {
            if (!await _gateway.SubmitAsync(recipients, dto.MessageContent, HttpContext.RequestAborted))
                return StatusCode(502, new { error = "رفضت بوابة الرسائل طلب الإرسال. لم يتم تأكيد الإرسال." });
        }
        catch (HttpRequestException) { return StatusCode(502, new { error = "تعذر الاتصال ببوابة الرسائل." }); }
        catch (TaskCanceledException) { return StatusCode(504, new { error = "انتهت مهلة الاتصال ببوابة الرسائل؛ حالة الطلب غير مؤكدة." }); }

        await AuditLogger.LogAsync(_db, HttpContext, "SendSmsNotification", $"إرسال رسالة SMS نصية إلى: {targetDescription} (عدد المستلمين: {recipients.Count}) بواسطة: {currentUser.FullName}");

        return Ok(new {
            message = $"قبلت بوابة SMS طلب الإرسال إلى {recipients.Count} مستلماً. قبول الطلب لا يؤكد وصول الرسالة.",
            status = "accepted",
            recipientCount = recipients.Count,
            target = targetDescription
        });
    }
}
