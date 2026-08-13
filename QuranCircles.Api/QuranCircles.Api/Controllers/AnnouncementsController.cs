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
        if (user.Role == UserRole.Teacher)
        {
            if (dto.TargetType == AnnouncementTarget.All || dto.TargetType == AnnouncementTarget.AllTeachers)
            {
                return BadRequest(new { error = "غير مسموح للمعلم إرسال تعاميم عامة لكافة المعلمين أو الجميع." });
            }

            if (dto.TargetType == AnnouncementTarget.Circle && dto.TargetId.HasValue)
            {
                var circle = await _db.Circles.FindAsync(dto.TargetId.Value);
                if (circle == null || circle.TeacherId != user.TeacherId)
                {
                    return BadRequest(new { error = "غير مسموح بالإرسال لحلقة لا تشرف عليها." });
                }
            }
            else if (dto.TargetType == AnnouncementTarget.Student && dto.TargetId.HasValue)
            {
                var student = await _db.Students.Include(s => s.Circle).FirstOrDefaultAsync(s => s.Id == dto.TargetId.Value);
                if (student == null || student.Circle == null || student.Circle.TeacherId != user.TeacherId)
                {
                    return BadRequest(new { error = "غير مسموح بالإرسال لطالب خارج حلقتك." });
                }
            }
            else if (dto.TargetType == AnnouncementTarget.Parent && dto.TargetId.HasValue)
            {
                var studentExists = await _db.Students.Include(s => s.Circle)
                    .AnyAsync(s => s.ParentId == dto.TargetId.Value && s.Circle != null && s.Circle.TeacherId == user.TeacherId);
                if (!studentExists)
                {
                    return BadRequest(new { error = "غير مسموح بالإرسال لولي أمر ليس لديه أبناء في حلقتك." });
                }
            }
        }
        else if (user.Role == UserRole.Parent)
        {
            if (dto.TargetType != AnnouncementTarget.Teacher || !dto.TargetId.HasValue)
            {
                return BadRequest(new { error = "غير مسموح لولي الأمر إلا بمراسلة معلم حلقة ابنه فقط." });
            }

            var childCircleTeachers = await _db.Students
                .Where(s => s.ParentId == user.ParentId && s.CircleId.HasValue)
                .Select(s => s.Circle!.TeacherId)
                .Distinct()
                .ToListAsync();

            if (!childCircleTeachers.Contains(dto.TargetId.Value))
            {
                return BadRequest(new { error = "المعلم المحدد ليس معلماً لأي من أبنائك." });
            }
        }
        else if (user.Role == UserRole.Student)
        {
            var myStudent = await _db.Students.Include(s => s.Circle).FirstOrDefaultAsync(s => s.Id == user.StudentId);
            if (myStudent == null || myStudent.Circle == null)
            {
                return BadRequest(new { error = "الطالب غير مسند لحلقة أو بيانات الطالب غير مكتملة." });
            }

            if (dto.TargetType == AnnouncementTarget.Circle && dto.TargetId == myStudent.CircleId)
            {
                // Allowed
            }
            else if (dto.TargetType == AnnouncementTarget.Teacher && dto.TargetId == myStudent.Circle.TeacherId)
            {
                // Allowed
            }
            else
            {
                return BadRequest(new { error = "غير مسموح للطالب إلا بمراسلة معلمه أو طلاب حلقته فقط." });
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
