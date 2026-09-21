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
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.Parent, UserRole.Student)]
    public async Task<IActionResult> Create([FromBody] CreateAnnouncementDto dto)
    {
        var userId = FakeAuth.GetUserId(HttpContext);
        if (!userId.HasValue) return Unauthorized(new { error = "جلسة غير صالحة." });

        var user = await _db.Users.FindAsync(userId.Value);
        if (user == null) return Unauthorized(new { error = "المستخدم غير موجود." });

        // Scoping & Validation
        bool isUserTeacher = user.Role == UserRole.Teacher || user.TeacherId.HasValue;
        if (user.Role == UserRole.Teacher || (isUserTeacher && dto.TargetType != AnnouncementTarget.Admin && (user.Role != UserRole.Parent || dto.TargetType != AnnouncementTarget.Teacher)))
        {
            int tId = user.TeacherId ?? 0;
            Teacher? teacherObj = null;
            if (tId > 0) teacherObj = await _db.Teachers.FindAsync(tId);
            if (teacherObj == null)
            {
                teacherObj = await _db.Teachers.FirstOrDefaultAsync(t => t.FullName == user.FullName);
                if (teacherObj != null) tId = teacherObj.Id;
            }

            var taskRole = teacherObj?.TaskRole ?? "";
            bool isSupervisorOrAdmin = taskRole.Contains("مشرف") || taskRole.Contains("موجه") || user.Role == UserRole.Admin || user.Role == UserRole.Developer;

            if (dto.TargetType == AnnouncementTarget.All || dto.TargetType == AnnouncementTarget.AllTeachers)
            {
                if (!isSupervisorOrAdmin)
                {
                    return BadRequest(new { error = "غير مسموح للمعلم إرسال تعاميم عامة لكافة المعلمين أو الجميع." });
                }
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
                if (circle == null || (!isSupervisorOrAdmin && circle.TeacherId != tId && circle.Teacher?.FullName != user.FullName))
                {
                    return BadRequest(new { error = "غير مسموح بالإرسال لحلقة لا تشرف عليها." });
                }
            }
            else if (dto.TargetType == AnnouncementTarget.Student && dto.TargetId.HasValue)
            {
                var student = await _db.Students.Include(s => s.Circle).ThenInclude(c => c.Teacher).FirstOrDefaultAsync(s => s.Id == dto.TargetId.Value);
                if (student == null || (!isSupervisorOrAdmin && student.Circle != null && student.Circle.TeacherId != tId && student.Circle.Teacher?.FullName != user.FullName))
                {
                    return BadRequest(new { error = "غير مسموح بالإرسال لطالب خارج حلقتك." });
                }
            }
            else if (dto.TargetType == AnnouncementTarget.Parent && dto.TargetId.HasValue)
            {
                // Allowed: teacher messaging a parent of students
            }
        }
        else if (user.Role == UserRole.Parent)
        {
            if (dto.TargetType == AnnouncementTarget.Admin)
            {
                // Allowed: Parent sending inquiry/message to Center Administration
            }
            else if (dto.TargetType == AnnouncementTarget.Teacher && dto.TargetId.HasValue)
            {
                var teacherExists = await _db.Teachers.AnyAsync(t => t.Id == dto.TargetId.Value);
                if (!teacherExists)
                {
                    return BadRequest(new { error = "المعلم المحدد غير موجود." });
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
            else if (dto.TargetType == AnnouncementTarget.Circle || dto.TargetType == AnnouncementTarget.Teacher)
            {
                // Allowed: Student messaging circle or teacher
            }
            else
            {
                return BadRequest(new { error = "غير مسموح للطالب إلا بمراسلة معلمه أو طلاب حلقته أو إدارة المركز." });
            }
        }

        var senderName = user.FullName;
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
