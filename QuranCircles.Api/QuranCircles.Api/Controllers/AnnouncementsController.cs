using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using System.Threading.Tasks;


namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/announcements")]
public class AnnouncementsController : ControllerBase
{
    private readonly AnnouncementService _svc;
    private readonly AppDbContext _db;

    public AnnouncementsController(AnnouncementService svc, AppDbContext db)
    {
        _svc = svc;
        _db = db;
    }

    [HttpGet("my")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Student, UserRole.Parent, UserRole.Developer, UserRole.ExamSupervisor)]
    public async Task<IActionResult> GetMy()
    {
        var userId = FakeAuth.GetUserId(HttpContext);
        if (!userId.HasValue) return Unauthorized(new { error = "جلسة غير صالحة." });
        return Ok(await _svc.GetMyAnnouncementsAsync(userId.Value));
    }

    [HttpPost]
    [Idempotent]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.Parent, UserRole.Student)]
    public async Task<IActionResult> Create([FromBody] CreateAnnouncementDto dto)
    {
        var userId = FakeAuth.GetUserId(HttpContext);
        if (!userId.HasValue) return Unauthorized(new { error = "جلسة غير صالحة." });

        var user = await _db.Users.FindAsync(userId.Value);
        if (user == null) return Unauthorized(new { error = "المستخدم غير موجود." });
        if (dto.TargetType == AnnouncementTarget.StudentCircle)
            return BadRequest(new { error = "نوع المستلمين غير صالح للنشر المباشر." });
        if ((dto.TargetType is AnnouncementTarget.All or AnnouncementTarget.AllTeachers) &&
            await _db.SystemSettings.AsNoTracking().AnyAsync(s => !s.AllowPublicAnnouncements))
            return BadRequest(new { error = "نشر التعميمات العامة معطل في إعدادات المركز." });

        // Scoping & Validation
        bool isUserTeacher = user.Role == UserRole.Teacher || user.TeacherId.HasValue;
        var teacher = user.TeacherId.HasValue ? await _db.Teachers.FindAsync(user.TeacherId.Value) : null;
        var qualityCapacity = string.Equals(dto.SenderCapacity, "Quality", StringComparison.OrdinalIgnoreCase);
        if (dto.SenderCapacity != null && !qualityCapacity && dto.SenderCapacity != "Teacher")
            return BadRequest(new { error = "صفة الإرسال غير صالحة." });
        if (qualityCapacity)
        {
            if (teacher?.IsActive != true || !TeacherPermissions.For(teacher).Contains("quality")) return Forbid();
            if (dto.TargetType == AnnouncementTarget.CircleTeachers) { }
            else if (dto.TargetType == AnnouncementTarget.Admin) { }
            else if (dto.TargetType == AnnouncementTarget.Teacher && dto.TargetId.HasValue &&
                     await _db.Circles.AnyAsync(c => c.IsActive && (c.TeacherId == dto.TargetId || c.AssistantTeacherId == dto.TargetId))) { }
            else return BadRequest(new { error = "مشرف الجودة يراسل معلمي الحلقات أو مدير المركز بهذه الصفة." });
        }
        else if (user.Role == UserRole.Teacher || (isUserTeacher && dto.TargetType != AnnouncementTarget.Admin && (user.Role != UserRole.Parent || dto.TargetType != AnnouncementTarget.Teacher)))
        {
            int tId = user.TeacherId ?? 0;
            if (teacher?.IsActive != true) return Forbid();
            var hasTeachingAssignment = await _db.Circles.AnyAsync(c => c.IsActive && (c.TeacherId == tId || c.AssistantTeacherId == tId)) ||
                                        await _db.Courses.AnyAsync(c => c.IsActive && c.TeacherId == tId);
            if (!hasTeachingAssignment && dto.TargetType != AnnouncementTarget.Admin)
                return BadRequest(new { error = "لا توجد حلقة أو دورة مسندة لك. اختر الإرسال بصفتك مشرف جودة." });

            if (dto.TargetType == AnnouncementTarget.All || dto.TargetType == AnnouncementTarget.AllTeachers)
            {
                return BadRequest(new { error = "غير مسموح للمعلم إرسال تعاميم عامة لكافة المعلمين أو الجميع." });
            }
            else if (dto.TargetType == AnnouncementTarget.Admin)
            {
                // Allowed: Teacher messaging center administration / director
            }
            else if (dto.TargetType == AnnouncementTarget.Teacher)
            {
                // Allowed: Teacher messaging another teacher
            }
            else if (dto.TargetType == AnnouncementTarget.Circle && dto.TargetId.HasValue)
            {
                var circle = await _db.Circles.Include(c => c.Teacher).FirstOrDefaultAsync(c => c.Id == dto.TargetId.Value);
                if (circle == null || (circle.TeacherId != tId && circle.AssistantTeacherId != tId))
                {
                    return BadRequest(new { error = "غير مسموح بالإرسال لحلقة لا تشرف عليها." });
                }
            }
            else if (dto.TargetType == AnnouncementTarget.Course && dto.TargetId.HasValue)
            {
                if (!await _db.Courses.AnyAsync(c => c.Id == dto.TargetId.Value && c.IsActive && c.TeacherId == tId))
                    return BadRequest(new { error = "غير مسموح بالإرسال لدورة غير مسندة إليك." });
            }
            else if (dto.TargetType == AnnouncementTarget.Student && dto.TargetId.HasValue)
            {
                var student = await _db.Students.Include(s => s.Circle).ThenInclude(c => c!.Teacher).FirstOrDefaultAsync(s => s.Id == dto.TargetId.Value);
                var teachesCourse = await _db.CourseEnrollments.AnyAsync(e => e.StudentId == dto.TargetId.Value && e.Course != null && e.Course.TeacherId == tId);
                if (student == null || (student.Circle?.TeacherId != tId && student.Circle?.AssistantTeacherId != tId && !teachesCourse))
                {
                    return BadRequest(new { error = "غير مسموح بالإرسال لطالب خارج حلقتك." });
                }
            }
            else if (dto.TargetType == AnnouncementTarget.Parent && dto.TargetId.HasValue)
            {
                var parent = await _db.Users.FirstOrDefaultAsync(p => p.Role != UserRole.Student && (p.Id == dto.TargetId || p.ParentId == dto.TargetId));
                if (parent == null) return BadRequest(new { error = "ولي الأمر المحدد غير موجود." });
                var childIds = await ParentLinks.ChildrenQuery(_db, parent).Select(s => s.Id).ToListAsync();
                var assigned = await _db.Students.AnyAsync(s => childIds.Contains(s.Id) && s.Circle != null && (s.Circle.TeacherId == tId || s.Circle.AssistantTeacherId == tId)) ||
                    await _db.CourseEnrollments.AnyAsync(e => childIds.Contains(e.StudentId) && e.Course != null && e.Course.TeacherId == tId);
                if (!assigned) return BadRequest(new { error = "ولي الأمر ليس ضمن حلقتك أو دورتك." });
            }
            else return BadRequest(new { error = "فئة المستلمين غير متاحة للمعلم." });
        }
        else if (user.Role == UserRole.Parent)
        {
            if (dto.TargetType == AnnouncementTarget.Admin)
            {
                // Allowed: Parent sending inquiry/message to Center Administration
            }
            else if (dto.TargetType == AnnouncementTarget.Teacher && dto.TargetId.HasValue)
            {
                var children = await ParentLinks.ChildrenQuery(_db, user).Select(s => s.Id).ToListAsync();
                var teacherAssigned = await _db.Students.AnyAsync(s => children.Contains(s.Id) && s.Circle != null && (s.Circle.TeacherId == dto.TargetId || s.Circle.AssistantTeacherId == dto.TargetId)) ||
                    await _db.CourseEnrollments.AnyAsync(e => children.Contains(e.StudentId) && e.Course != null && e.Course.TeacherId == dto.TargetId);
                if (!teacherAssigned)
                {
                    return BadRequest(new { error = "المعلم ليس مسنداً لأي من أبنائك." });
                }
            }
            else if (isUserTeacher)
            {
                // Allowed: Dual-role parent who is also teacher
            }
            else
            {
                return BadRequest(new { error = "يمكن لولي الأمر مراسلة معلم حلقة ابنه أو معلم الدورة أو إدارة المركز." });
            }
        }
        else if (user.Role == UserRole.Student)
        {
            if (dto.TargetType == AnnouncementTarget.Admin)
            {
                // Allowed: Student sending to Center Administration
            }
            else if (dto.TargetType == AnnouncementTarget.Circle && dto.TargetId.HasValue)
            {
                var ownsCircle = await _db.Students.AnyAsync(s => s.Id == user.StudentId && s.CircleId == dto.TargetId && s.Circle != null && s.Circle.IsActive);
                if (!ownsCircle) return BadRequest(new { error = "يمكنك النشر لطلاب حلقتك فقط." });
                dto = dto with { TargetType = AnnouncementTarget.StudentCircle, TargetId = user.StudentId };
            }
            else if (dto.TargetType == AnnouncementTarget.Teacher && dto.TargetId.HasValue)
            {
                var assigned = await _db.Students.AnyAsync(s => s.Id == user.StudentId && s.Circle != null && (s.Circle.TeacherId == dto.TargetId || s.Circle.AssistantTeacherId == dto.TargetId)) ||
                    await _db.CourseEnrollments.AnyAsync(e => e.StudentId == user.StudentId && e.Course != null && e.Course.TeacherId == dto.TargetId);
                if (!assigned) return BadRequest(new { error = "المعلم غير مسند لحلقتك أو دورتك." });
            }
            else
            {
                return BadRequest(new { error = "غير مسموح للطالب إلا بمراسلة معلمه أو طلاب حلقته أو إدارة المركز." });
            }
        }

        var senderName = qualityCapacity ? $"{user.FullName} (مشرف الجودة)" : user.FullName;
        var (created, error) = await _svc.CreateAnnouncementAsync(dto, senderName);
        if (error is not null) return BadRequest(new { error });

        return Ok(created);
    }

    [HttpDelete("clear-all")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> ClearAll()
    {
        _db.Announcements.RemoveRange(_db.Announcements);
        await _db.SaveChangesAsync();
        return Ok(new { message = "تم مسح كافة الإعلانات والتعاميم بنجاح." });
    }

    [HttpDelete("{id}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Delete(int id)
    {
        var item = await _db.Announcements.FindAsync(id);
        if (item == null) return NotFound(new { error = "الإعلان غير موجود." });
        _db.Announcements.Remove(item);
        await _db.SaveChangesAsync();
        return Ok(new { message = "تم حذف الإعلان بنجاح." });
    }
}
