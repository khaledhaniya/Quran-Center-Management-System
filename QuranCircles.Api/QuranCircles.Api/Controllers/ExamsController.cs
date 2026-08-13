using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ExamsController : ControllerBase
{
    private readonly AppDbContext _db;

    public ExamsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpPost("nominate")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> Nominate([FromBody] CreateNominationDto dto)
    {
        var student = await _db.Students
            .Include(s => s.Circle)
            .FirstOrDefaultAsync(s => s.Id == dto.StudentId);
        if (student == null) return NotFound(new { Message = "الطالب غير موجود." });

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        if (currentUser.Role == UserRole.Teacher)
        {
            if (dto.NominationType == "Quran")
            {
                if (student.Circle == null || student.Circle.TeacherId != currentUser.TeacherId)
                {
                    return BadRequest(new { Message = "لا يمكنك ترشيح طالب من غير حلقتك لاختبار الأجزاء." });
                }
            }
            else if (dto.NominationType == "Course")
            {
                if (!dto.CourseId.HasValue)
                {
                    return BadRequest(new { Message = "يجب تحديد الدورة للترشيح." });
                }
                var course = await _db.Courses.FirstOrDefaultAsync(c => c.Id == dto.CourseId.Value);
                if (course == null)
                {
                    return BadRequest(new { Message = "الدورة غير موجودة." });
                }
                if (course.TeacherId != currentUser.TeacherId)
                {
                    return BadRequest(new { Message = "أنت لست معلم هذه الدورة، لا يمكنك ترشيح الطلاب لها." });
                }
                var enrolled = await _db.CourseEnrollments.AnyAsync(ce => ce.StudentId == student.Id && ce.CourseId == dto.CourseId.Value);
                if (!enrolled)
                {
                    return BadRequest(new { Message = "الطالب غير مسجل في هذه الدورة." });
                }
            }
            else
            {
                return BadRequest(new { Message = "نوع الترشيح غير صالح." });
            }
        }
        else
        {
            if (dto.NominationType == "Course")
            {
                if (!dto.CourseId.HasValue)
                {
                    return BadRequest(new { Message = "يجب تحديد الدورة للترشيح." });
                }
                var enrolled = await _db.CourseEnrollments.AnyAsync(ce => ce.StudentId == student.Id && ce.CourseId == dto.CourseId.Value);
                if (!enrolled)
                {
                    return BadRequest(new { Message = "الطالب غير مسجل في هذه الدورة." });
                }
            }
        }

        int teacherId = 0;
        if (currentUser.Role == UserRole.Teacher)
        {
            teacherId = currentUser.TeacherId ?? 0;
        }
        else
        {
            if (dto.NominationType == "Course" && dto.CourseId.HasValue)
            {
                var course = await _db.Courses.FindAsync(dto.CourseId.Value);
                teacherId = course?.TeacherId ?? student.Circle?.TeacherId ?? _db.Teachers.FirstOrDefault()?.Id ?? 0;
            }
            else
            {
                teacherId = student.Circle?.TeacherId ?? _db.Teachers.FirstOrDefault()?.Id ?? 0;
            }
        }

        var nomination = new ExamNomination
        {
            StudentId = dto.StudentId,
            TeacherId = teacherId,
            NominationType = dto.NominationType,
            CourseId = dto.CourseId,
            JuzStart = dto.JuzStart,
            JuzEnd = dto.JuzEnd,
            Status = "Pending",
            NominationDate = DateOnly.FromDateTime(DateTime.Today)
        };

        _db.ExamNominations.Add(nomination);
        await _db.SaveChangesAsync();

        _db.AuditLogs.Add(new AuditLog
        {
            Username = currentUser.Username,
            Action = "NominateExam",
            Details = $"ترشيح الطالب {student.FullName} لاختبار {dto.NominationType} " +
                      (dto.NominationType == "Quran" ? $"للأجزاء {dto.JuzStart} - {dto.JuzEnd}" : $"للمساق {dto.CourseId}"),
            Timestamp = DateTime.UtcNow,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
        });
        await _db.SaveChangesAsync();

        return Ok(new { Message = "تم تقديم طلب الترشيح بنجاح.", NominationId = nomination.Id });
    }

    [HttpGet("student/{studentId:int}")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> GetStudentNominations(int studentId)
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        var student = await _db.Students.FindAsync(studentId);
        if (student == null) return NotFound(new { Message = "الطالب غير موجود." });

        if (currentUser.Role == UserRole.Teacher)
        {
            if (!student.CircleId.HasValue || !await _db.Circles.AnyAsync(c => c.Id == student.CircleId.Value && c.TeacherId == currentUser.TeacherId))
            {
                return Forbid();
            }
        }
        var list = await _db.ExamNominations
            .Include(n => n.Student)
            .ThenInclude(s => s!.Circle)
            .Include(n => n.Teacher)
            .Include(n => n.Course)
            .Include(n => n.Result)
            .Where(n => n.StudentId == studentId)
            .Select(n => new
            {
                n.Id,
                n.StudentId,
                StudentName = n.Student != null ? n.Student.FullName : "",
                HalaqahName = (n.Student != null && n.Student.Circle != null) ? n.Student.Circle.Name : "بدون حلقة",
                TeacherName = n.Teacher != null ? n.Teacher.FullName : "",
                n.NominationType,
                n.CourseId,
                CourseName = n.Course != null ? n.Course.Name : "",
                n.JuzStart,
                n.JuzEnd,
                n.Status,
                n.NominationDate,
                n.ExamDate,
                Result = n.Result != null ? new
                {
                    n.Result.Id,
                    n.Result.MajorMistakes,
                    n.Result.MinorMistakes,
                    n.Result.Grade,
                    n.Result.Notes,
                    n.Result.ExamDate
                } : null
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpGet("nominations")]
    public async Task<IActionResult> GetNominations()
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        var query = _db.ExamNominations
            .Include(n => n.Student)
            .ThenInclude(s => s!.Circle)
            .Include(n => n.Teacher)
            .Include(n => n.Course)
            .Include(n => n.Result)
            .AsQueryable();

        if (currentUser.Role == UserRole.Teacher)
        {
            query = query.Where(n => 
                (n.Student != null && n.Student.Circle != null && n.Student.Circle.TeacherId == currentUser.TeacherId) ||
                (n.Course != null && n.Course.TeacherId == currentUser.TeacherId) ||
                n.TeacherId == currentUser.TeacherId
            );
        }
        else if (currentUser.Role == UserRole.ExamSupervisor || currentUser.Role == UserRole.Admin || currentUser.Role == UserRole.Developer)
        {
            // Exam Supervisors, Admins, and Developers can see all nominations
        }
        else if (currentUser.Role == UserRole.Student)
        {
            query = query.Where(n => n.StudentId == currentUser.StudentId);
        }
        else if (currentUser.Role == UserRole.Parent)
        {
            var studentIds = await _db.Students
                .Where(s => s.ParentId == currentUser.ParentId)
                .Select(s => s.Id)
                .ToListAsync();
            query = query.Where(n => studentIds.Contains(n.StudentId));
        }

        var list = await query
            .Select(n => new
            {
                n.Id,
                n.StudentId,
                StudentName = n.Student != null ? n.Student.FullName : "",
                HalaqahName = (n.Student != null && n.Student.Circle != null) ? n.Student.Circle.Name : "بدون حلقة",
                TeacherName = n.Teacher != null ? n.Teacher.FullName : "",
                n.NominationType,
                n.CourseId,
                CourseName = n.Course != null ? n.Course.Name : "",
                n.JuzStart,
                n.JuzEnd,
                n.Status,
                n.NominationDate,
                n.ExamDate,
                Result = n.Result != null ? new
                {
                    n.Result.Id,
                    n.Result.MajorMistakes,
                    n.Result.MinorMistakes,
                    n.Result.Grade,
                    n.Result.Notes,
                    n.Result.ExamDate
                } : null
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpPut("schedule")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.ExamSupervisor)]
    public async Task<IActionResult> Schedule([FromBody] ScheduleExamDto dto)
    {
        var nomination = await _db.ExamNominations
            .Include(n => n.Student)
            .Include(n => n.Course)
            .FirstOrDefaultAsync(n => n.Id == dto.NominationId);

        if (nomination == null) return NotFound(new { Message = "طلب الترشيح غير موجود." });

        nomination.Status = "Scheduled";
        nomination.ExamDate = dto.ExamDate;

        var student = nomination.Student;
        int? teacherId = nomination.Course?.TeacherId;
        if (!teacherId.HasValue && student?.CircleId.HasValue == true)
        {
            var circle = await _db.Circles.FindAsync(student.CircleId.Value);
            teacherId = circle?.TeacherId;
        }
        int? parentId = student?.ParentId;

        string examTypeName = nomination.NominationType == "Quran" ? "حفظ قرآن كريم" : $"دورة ({(nomination.Course != null ? nomination.Course.Name : "شرعية")})";
        string msgTitle = "إشعار موعد اختبار مجدول";
        string msgContent = $"تم تحديد وتأكيد موعد اختبار {examTypeName} للطالب ({student?.FullName}) بتاريخ: {dto.ExamDate}.";

        if (student != null)
        {
            _db.Announcements.Add(new Announcement { Title = msgTitle, Content = msgContent, TargetType = AnnouncementTarget.Student, TargetId = student.Id, DateTimeSent = DateTime.UtcNow, SenderName = "مشرف الاختبارات" });
        }
        if (teacherId.HasValue)
        {
            _db.Announcements.Add(new Announcement { Title = msgTitle, Content = msgContent, TargetType = AnnouncementTarget.Teacher, TargetId = teacherId.Value, DateTimeSent = DateTime.UtcNow, SenderName = "مشرف الاختبارات" });
        }
        if (parentId.HasValue)
        {
            _db.Announcements.Add(new Announcement { Title = msgTitle, Content = msgContent, TargetType = AnnouncementTarget.Parent, TargetId = parentId.Value, DateTimeSent = DateTime.UtcNow, SenderName = "مشرف الاختبارات" });
        }

        await _db.SaveChangesAsync();

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        _db.AuditLogs.Add(new AuditLog
        {
            Username = currentUser?.Username ?? "Unknown",
            Action = "ScheduleExam",
            Details = $"جدولة اختبار الطالب {nomination.Student!.FullName} بتاريخ {dto.ExamDate}",
            Timestamp = DateTime.UtcNow,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
        });
        await _db.SaveChangesAsync();

        return Ok(new { Message = "تم جدولة الاختبار وتعيين الموعد وإرسال الإشعارات بنجاح." });
    }

    [HttpPost("evaluate")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.ExamSupervisor)]
    public async Task<IActionResult> Evaluate([FromBody] EvaluateExamDto dto)
    {
        var nomination = await _db.ExamNominations
            .Include(n => n.Student)
            .Include(n => n.Course)
            .FirstOrDefaultAsync(n => n.Id == dto.NominationId);

        if (nomination == null) return NotFound(new { Message = "طلب الترشيح غير موجود." });

        var code2FA = HttpContext.Request.Headers["X-2FA-Code"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(code2FA) || code2FA != "123456")
        {
            return BadRequest(new { Message = "رمز التحقق الثنائي (2FA) غير صحيح أو مفقود. رمز التوجيه هو: 123456" });
        }

        var result = new ExamResult
        {
            ExamNominationId = nomination.Id,
            MajorMistakes = dto.MajorMistakes,
            MinorMistakes = dto.MinorMistakes,
            Grade = dto.Grade,
            Notes = dto.Notes,
            ExamDate = DateTime.UtcNow
        };

        nomination.Status = dto.Grade >= 60 ? "Completed" : "Failed";
        nomination.Result = result;
        _db.ExamResults.Add(result);

        var student = nomination.Student;
        int? teacherId = nomination.Course?.TeacherId;
        if (!teacherId.HasValue && student?.CircleId.HasValue == true)
        {
            var circle = await _db.Circles.FindAsync(student.CircleId.Value);
            teacherId = circle?.TeacherId;
        }
        int? parentId = student?.ParentId;

        string resultText = dto.Grade >= 60 ? "مكتمـل واجتـاز بنجـاح" : "مكتمـل ولم يجتـز";
        string examTypeName = nomination.NominationType == "Quran" ? "حفظ قرآن كريم" : $"دورة ({(nomination.Course != null ? nomination.Course.Name : "شرعية")})";
        string msgTitle = "إشعار اعتماد نتيجة اختبار";
        string msgContent = $"تم رصد واعتتماد نتيجة اختبار {examTypeName} للطالب ({student?.FullName}) بدرجة ({dto.Grade}%) - حالة الاختبار: ({resultText}).";

        if (student != null)
        {
            _db.Announcements.Add(new Announcement { Title = msgTitle, Content = msgContent, TargetType = AnnouncementTarget.Student, TargetId = student.Id, DateTimeSent = DateTime.UtcNow, SenderName = "مشرف الاختبارات" });
        }
        if (teacherId.HasValue)
        {
            _db.Announcements.Add(new Announcement { Title = msgTitle, Content = msgContent, TargetType = AnnouncementTarget.Teacher, TargetId = teacherId.Value, DateTimeSent = DateTime.UtcNow, SenderName = "مشرف الاختبارات" });
        }
        if (parentId.HasValue)
        {
            _db.Announcements.Add(new Announcement { Title = msgTitle, Content = msgContent, TargetType = AnnouncementTarget.Parent, TargetId = parentId.Value, DateTimeSent = DateTime.UtcNow, SenderName = "مشرف الاختبارات" });
        }

        await _db.SaveChangesAsync();

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        _db.AuditLogs.Add(new AuditLog
        {
            Username = currentUser?.Username ?? "Unknown",
            Action = "EvaluateExam",
            Details = $"رصد علامة اختبار الطالب {nomination.Student!.FullName} بدرجة {dto.Grade}%",
            Timestamp = DateTime.UtcNow,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
        });
        await _db.SaveChangesAsync();

        return Ok(new { Message = "تم رصد علامة الاختبار وإرسال التنبيهات بنجاح.", Grade = dto.Grade });
    }
}
