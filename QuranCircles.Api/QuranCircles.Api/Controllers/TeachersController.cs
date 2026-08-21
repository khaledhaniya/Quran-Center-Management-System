using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using System.Linq;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/teachers")]
public class TeachersController : ControllerBase
{
    private readonly TeacherService _svc;
    private readonly AppDbContext _db;

    public TeachersController(TeacherService svc, AppDbContext db)
    {
        _svc = svc;
        _db = db;
    }

    [HttpGet]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> GetAll([FromQuery] string? search)
        => Ok(await _svc.GetAllAsync(search));

    [HttpGet("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> Get(int id)
    {
        var t = await _svc.GetByIdAsync(id);
        return t is null ? NotFound(new { error = "المعلّم غير موجود." }) : Ok(t);
    }

    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Create([FromBody] CreateTeacherDto dto)
    {
        var (created, error) = await _svc.CreateAsync(dto);
        if (error is not null) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "CreateTeacher", $"إضافة معلم جديد: {created!.FullName}");

        return CreatedAtAction(nameof(Get), new { id = created!.Id }, created);
    }

    [HttpPut("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateTeacherDto dto)
    {
        var (ok, error) = await _svc.UpdateAsync(id, dto);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "UpdateTeacher", $"تعديل بيانات المعلم: {dto.FullName} (ID: #{id})");

        return NoContent();
    }

    [HttpDelete("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Deactivate(int id)
    {
        var ok = await _svc.DeactivateAsync(id);
        if (ok)
        {
            await AuditLogger.LogAsync(_db, HttpContext, "DeactivateTeacher", $"تعطيل حساب المعلم ID: #{id}");
        }
        return ok ? NoContent() : NotFound(new { error = "المعلّم غير موجود." });
    }

    [HttpDelete("{id:int}/permanent")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> HardDelete(int id)
    {
        var (ok, teacherName, error) = await _svc.HardDeleteAsync(id);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "HardDeleteTeacher", $"حذف معلم نهائياً: {teacherName} (ID: #{id}) وحسابه بالتنسيق");

        return Ok(new { Message = $"تم حذف المعلم ({teacherName}) نهائياً من النظام." });
    }

    [HttpPost("{id:int}/toggle-active")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> ToggleActive(int id)
    {
        var (ok, newStatus, error) = await _svc.ToggleActiveAsync(id);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "ToggleActiveTeacher", $"تغيير حالة تفعيل المعلم ID #{id} إلى: {(newStatus ? "نشط" : "معطل")}");

        return Ok(new { Message = newStatus ? "تم تنشيط المعلم بنجاح." : "تم تعطيل المعلم بنجاح.", IsActive = newStatus });
    }

    [HttpGet("{id:int}/comprehensive-report")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> GetTeacherComprehensiveReport(int id)
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        
        Teacher? teacher = null;
        if (currentUser?.Role == UserRole.Teacher)
        {
            if (currentUser.TeacherId.HasValue && currentUser.TeacherId.Value > 0)
            {
                teacher = await _db.Teachers.FindAsync(currentUser.TeacherId.Value);
            }
            if (teacher == null)
            {
                teacher = await _db.Teachers.FirstOrDefaultAsync(t => t.FullName == currentUser.FullName || t.Id == id || t.Id == currentUser.Id);
            }
        }
        else
        {
            teacher = await _db.Teachers.FindAsync(id);
            if (teacher == null && id > 0)
            {
                var userT = await _db.Users.FindAsync(id);
                if (userT != null && userT.TeacherId.HasValue)
                {
                    teacher = await _db.Teachers.FindAsync(userT.TeacherId.Value);
                }
            }
        }

        if (teacher == null) return NotFound(new { error = "المعلم غير موجود." });

        var circles = await _db.Circles
            .Where(c => c.TeacherId == teacher.Id)
            .Select(c => c.Id)
            .ToListAsync();

        var students = await _db.Students
            .Include(s => s.Circle)
            .Include(s => s.Sessions)
            .Include(s => s.AttendanceRecords)
            .Where(s => s.CircleId.HasValue && circles.Contains(s.CircleId.Value))
            .ToListAsync();

        var studentIds = students.Select(s => s.Id).ToList();

        var courseEnrollments = await _db.CourseEnrollments
            .Include(ce => ce.Course)
            .Where(ce => studentIds.Contains(ce.StudentId))
            .ToListAsync();

        var courseAttendances = await _db.CourseAttendances
            .Include(ca => ca.Course)
            .Where(ca => studentIds.Contains(ca.StudentId))
            .ToListAsync();

        var report = students.Select(s =>
        {
            var totalAtt = s.AttendanceRecords.Count;
            var presentCount = s.AttendanceRecords.Count(a => a.Status == AttendanceStatus.Present);
            var absentCount = s.AttendanceRecords.Count(a => a.Status == AttendanceStatus.Absent);
            var lateCount = s.AttendanceRecords.Count(a => a.Status == AttendanceStatus.Late);
            var attRate = totalAtt > 0 ? (int)Math.Round((double)presentCount / totalAtt * 100) : 100;

            return new
            {
                s.Id,
                s.FullName,
                s.StudentIdentityNumber,
                s.FamilyContact,
                s.StudentMobile,
                s.Address,
                s.IsActive,
                CircleName = s.Circle != null ? s.Circle.Name : "بدون حلقة",
                s.TargetAjzaaCount,
                s.PlanType,
                s.DailyPacePages,
                s.CompletedAjzaa,
                // Attendance Summary
                TotalAttendanceDays = totalAtt,
                PresentDaysCount = presentCount,
                AbsentDaysCount = absentCount,
                LateDaysCount = lateCount,
                AttendanceRatePercentage = attRate,
                AttendanceRecords = s.AttendanceRecords.OrderByDescending(a => a.SessionDate).Select(a => new
                {
                    a.Id,
                    Date = a.SessionDate.ToString("yyyy-MM-dd"),
                    SessionDate = a.SessionDate.ToString("yyyy-MM-dd"),
                    Status = (int)a.Status,
                    StatusText = a.Status == AttendanceStatus.Present ? "حاضر" : (a.Status == AttendanceStatus.Absent ? "غائب" : "متأخر")
                }),
                // Recitation Sessions
                TotalRecitationSessions = s.Sessions.Count,
                RecitationSessions = s.Sessions.OrderByDescending(rs => rs.SessionDate).Select(rs => new
                {
                    rs.Id,
                    Date = rs.SessionDate.ToString("yyyy-MM-dd"),
                    SessionDate = rs.SessionDate.ToString("yyyy-MM-dd"),
                    rs.SurahName,
                    rs.FromVerse,
                    rs.ToVerse,
                    Assessment = rs.Assessment.ToString(),
                    AssessmentText = rs.Assessment == AssessmentLevel.Excellent ? "ممتاز" : (rs.Assessment == AssessmentLevel.VeryGood ? "جيد جداً" : (rs.Assessment == AssessmentLevel.Good ? "جيد" : (rs.Assessment == AssessmentLevel.Medium ? "متوسط" : "مرفوض"))),
                    rs.Notes,
                    rs.ViaLottery
                }),
                // Courses & Course Attendance
                Courses = courseEnrollments.Where(ce => ce.StudentId == s.Id).Select(ce => new
                {
                    ce.CourseId,
                    CourseName = ce.Course != null ? ce.Course.Name : "",
                    ce.Status,
                    ce.Grade,
                    ce.CertificateCode,
                    PresentCount = courseAttendances.Count(ca => ca.StudentId == s.Id && ca.CourseId == ce.CourseId && ca.Status == AttendanceStatus.Present),
                    AbsentCount = courseAttendances.Count(ca => ca.StudentId == s.Id && ca.CourseId == ce.CourseId && ca.Status == AttendanceStatus.Absent),
                    Attendances = courseAttendances.Where(ca => ca.StudentId == s.Id && ca.CourseId == ce.CourseId).Select(ca => new
                    {
                        Date = ca.SessionDate.ToString("yyyy-MM-dd"),
                        Status = (int)ca.Status,
                        StatusText = ca.Status == AttendanceStatus.Present ? "حاضر" : (ca.Status == AttendanceStatus.Absent ? "غائب" : "متأخر")
                    })
                })
            };
        }).ToList();

        return Ok(new
        {
            TeacherId = teacher.Id,
            TeacherName = teacher.FullName,
            TotalStudents = students.Count,
            Students = report
        });
    }
}
