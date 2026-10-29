using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
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
    [Idempotent]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Parent, UserRole.Developer)]
    public async Task<IActionResult> Nominate([FromBody] CreateNominationDto dto)
    {
        var student = await _db.Students
            .Include(s => s.Circle)
            .FirstOrDefaultAsync(s => s.Id == dto.StudentId);
        if (student == null) return NotFound(new { Message = "الطالب غير موجود." });

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        var actsAsTeacher = (currentUser.Role == UserRole.Teacher || currentUser.Role == UserRole.Parent) && currentUser.TeacherId.HasValue;
        if (currentUser.Role == UserRole.Parent && !actsAsTeacher) return Forbid();
        if (actsAsTeacher)
        {
            if (!currentUser.TeacherId.HasValue || !await _db.Teachers.AnyAsync(t => t.Id == currentUser.TeacherId.Value && t.IsActive))
                return Forbid();
            if ((dto.NominationType == "Quran" || dto.NominationType == "Combined"))
            {
                if (student.Circle?.IsActive != true || (student.Circle.TeacherId != currentUser.TeacherId && student.Circle.AssistantTeacherId != currentUser.TeacherId))
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
                if (!course.IsActive || course.TeacherId != currentUser.TeacherId)
                {
                    return BadRequest(new { Message = "أنت لست معلم هذه الدورة، لا يمكنك ترشيح الطلاب لها." });
                }
                var enrolled = await _db.CourseEnrollments.AnyAsync(ce => ce.StudentId == student.Id && ce.CourseId == dto.CourseId.Value);
                if (!enrolled)
                {
                    return BadRequest(new { Message = "الطالب غير مسجل في هذه الدورة." });
                }
                var settings = await _db.SystemSettings.FirstOrDefaultAsync() ?? new SystemSettings();
                if (settings.MinAttendancePercentForExam > 0)
                {
                    var records = await _db.CourseAttendances.Where(a => a.CourseId == dto.CourseId && a.StudentId == student.Id).ToListAsync();
                    if (records.Count > 0)
                    {
                        var attendanceRate = Math.Round(100d * records.Count(a => a.Status is AttendanceStatus.Present or AttendanceStatus.Late) / records.Count, 1);
                        if (attendanceRate < settings.MinAttendancePercentForExam)
                            return BadRequest(new { Message = $"نسبة حضور الطالب {attendanceRate}% أقل من الحد المطلوب {settings.MinAttendancePercentForExam}%. يلزم استثناء من إدارة المركز." });
                    }
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
        if (actsAsTeacher)
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

        if (!new[] { "Quran", "Course", "Combined" }.Contains(dto.NominationType)) return BadRequest(new { Message = "نوع الترشيح غير صالح." });
        if (dto.NominationType == "Combined" && (!dto.JuzStart.HasValue || !dto.JuzEnd.HasValue || dto.JuzStart < 1 || dto.JuzEnd > 30 || dto.JuzEnd < dto.JuzStart ||
            !new[] { 5, 10, 15, 20, 30 }.Contains(dto.JuzEnd.Value - dto.JuzStart.Value + 1)))
            return BadRequest(new { Message = "حدد سلسلة مجتمعة من 5 أو 10 أو 15 أو 20 أو 30 جزءاً." });
        if (dto.NominationType == "Combined" && await _db.ExamNominations.AnyAsync(e => e.StudentId == dto.StudentId && e.NominationType == "Combined" && e.JuzStart == dto.JuzStart && e.JuzEnd == dto.JuzEnd && (e.Status == "Pending" || e.Status == "Scheduled" || e.Status == "Completed")))
            return Conflict(new { Message = "هذه السلسلة مرشحة مسبقاً للطالب." });
        if (dto.NominationType == "Course" && await _db.CourseEnrollments.AnyAsync(e => e.StudentId == dto.StudentId && e.CourseId == dto.CourseId && (e.Status == "Passed" || e.Status == "Certified")))
            return Conflict(new { Message = "الطالب اجتاز هذه الدورة سابقاً؛ لا يمكن إعادة ترشيحه." });
        if (dto.NominationType != "Combined" && await _db.ExamNominations.AnyAsync(e =>
            e.StudentId == dto.StudentId && e.NominationType == dto.NominationType &&
            (dto.NominationType == "Course" ? e.CourseId == dto.CourseId : e.JuzStart == dto.JuzStart && e.JuzEnd == dto.JuzEnd) &&
            (e.Status == "Pending" || e.Status == "Scheduled" || e.Status == "Completed")))
            return Conflict(new { Message = "الطالب مرشح بالفعل لهذا الاختبار أو اجتازه. لا يمكن تكرار الترشيح." });

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
                      ((dto.NominationType == "Quran" || dto.NominationType == "Combined") ? $"للأجزاء {dto.JuzStart} - {dto.JuzEnd}" : $"للمساق {dto.CourseId}"),
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
            var ownsCircle = student.CircleId.HasValue && await _db.Circles.AnyAsync(c => c.Id == student.CircleId.Value && (c.TeacherId == currentUser.TeacherId || c.AssistantTeacherId == currentUser.TeacherId));
            var ownsCourse = await _db.CourseEnrollments.AnyAsync(e => e.StudentId == studentId && e.Course != null && e.Course.TeacherId == currentUser.TeacherId);
            if (!ownsCircle && !ownsCourse)
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
        var currentUser = await _db.Users.Include(u => u.Teacher)
            .FirstOrDefaultAsync(u => u.Id == currentUserId);
        if (currentUser == null) return Unauthorized();

        var currentTeacher = currentUser.TeacherId.HasValue ? await _db.Teachers.FindAsync(currentUser.TeacherId.Value) : null;
        bool isGeneralSupervisor = currentUser.Role == UserRole.Admin ||
                                   currentUser.Role == UserRole.Developer ||
                                   currentUser.Role == UserRole.ExamSupervisor ||
                                   (currentTeacher?.IsActive == true && currentTeacher.TaskRole != null && currentTeacher.TaskRole.Contains("مشرف اختبارات"));
        bool canSeeAllForQuality = currentTeacher?.IsActive == true &&
                                   TeacherPermissions.For(currentTeacher).Contains("quality");

        var query = _db.ExamNominations
            .Include(n => n.Student)
                .ThenInclude(s => s!.Circle)
                    .ThenInclude(c => c!.Teacher)
            .Include(n => n.Teacher)
            .Include(n => n.Course)
                .ThenInclude(c => c!.Teacher)
            .Include(n => n.Result)
            .AsQueryable();

        if (isGeneralSupervisor || canSeeAllForQuality)
        {
            // Exam Supervisors, Admins, and Developers can see all nominations
        }
        else if (currentUser.Role == UserRole.Teacher && currentTeacher?.IsActive != true)
        {
            var ownChildrenIds = await ParentLinks.ChildrenQuery(_db, currentUser).Select(s => s.Id).ToListAsync();
            query = query.Where(n => ownChildrenIds.Contains(n.StudentId));
        }
        else if (currentUser.Role == UserRole.Teacher || (currentUser.Role == UserRole.Parent && currentTeacher?.IsActive == true))
        {
            var ownChildrenIds = await ParentLinks.ChildrenQuery(_db, currentUser)
                .Select(s => s.Id).ToListAsync();
            query = query.Where(n =>
                ownChildrenIds.Contains(n.StudentId) ||
                (n.Student != null && n.Student.Circle != null &&
                    (n.Student.Circle.TeacherId == currentUser.TeacherId || n.Student.Circle.AssistantTeacherId == currentUser.TeacherId)) ||
                (n.NominationType == "Course" && n.Course != null && n.Course.TeacherId == currentUser.TeacherId) ||
                (n.Course != null && (n.Course.ExamSupervisorId == currentUser.Id || (currentUser.TeacherId.HasValue && n.Course.ExamSupervisorId == currentUser.TeacherId.Value)))
            );
        }
        else if (currentUser.Role == UserRole.Student)
        {
            query = query.Where(n => n.StudentId == currentUser.StudentId);
        }
        else if (currentUser.Role == UserRole.Parent)
        {
            var children = await _db.Students.AsNoTracking().ToListAsync();
            var studentIds = children.Where(s => ParentLinks.IsChild(currentUser, s))
                .Select(s => s.Id).ToList();
            query = query.Where(n => studentIds.Contains(n.StudentId));
        }
        else return Forbid();

        var nominationsList = await query.ToListAsync();

        var list = nominationsList.Select(n =>
        {
            bool canManage = isGeneralSupervisor || (n.Course != null && (
                n.Course.ExamSupervisorId == currentUser.Id ||
                (currentUser.TeacherId.HasValue && n.Course.ExamSupervisorId == currentUser.TeacherId.Value)
            ));

            string resolvedTeacherName = "";
            if (n.NominationType == "Course" && n.Course?.Teacher != null)
            {
                resolvedTeacherName = n.Course.Teacher.FullName;
            }
            else if (n.Teacher != null)
            {
                resolvedTeacherName = n.Teacher.FullName;
            }
            else if (n.Student?.Circle?.Teacher != null)
            {
                resolvedTeacherName = n.Student.Circle.Teacher.FullName;
            }

            return new
            {
                n.Id,
                n.StudentId,
                StudentName = n.Student != null ? n.Student.FullName : "",
                HalaqahName = (n.Student != null && n.Student.Circle != null) ? n.Student.Circle.Name : "بدون حلقة",
                TeacherName = resolvedTeacherName,
                n.NominationType,
                n.CourseId,
                CourseName = n.Course != null ? n.Course.Name : "",
                n.JuzStart,
                n.JuzEnd,
                n.Status,
                n.NominationDate,
                n.ExamDate,
                CanSchedule = canManage,
                CanEvaluate = canManage,
                Result = n.Result != null ? new
                {
                    n.Result.Id,
                    n.Result.MajorMistakes,
                    n.Result.MinorMistakes,
                    n.Result.Grade,
                    n.Result.Notes,
                    n.Result.ExamDate
                } : null
            };
        }).ToList();

        return Ok(list);
    }

    [HttpPut("schedule")]
    [Idempotent]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.ExamSupervisor, UserRole.Teacher, UserRole.Parent)]
    public async Task<IActionResult> Schedule([FromBody] ScheduleExamDto dto)
    {
        var nomination = await _db.ExamNominations
            .Include(n => n.Student)
            .Include(n => n.Course)
            .FirstOrDefaultAsync(n => n.Id == dto.NominationId);

        if (nomination == null) return NotFound(new { Message = "طلب الترشيح غير موجود." });
        if (nomination.Status != "Pending") return BadRequest(new { Message = "لا يمكن جدولة اختبار لم يعد بانتظار الجدولة." });

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        var currentTeacher = currentUser.TeacherId.HasValue ? await _db.Teachers.FindAsync(currentUser.TeacherId.Value) : null;
        if ((currentUser.Role == UserRole.Parent || currentUser.Role == UserRole.Teacher) && currentTeacher?.IsActive != true) return Forbid();
        bool isGeneralSupervisor = currentUser.Role == UserRole.Admin ||
                                   currentUser.Role == UserRole.Developer ||
                                   currentUser.Role == UserRole.ExamSupervisor ||
                                   (currentTeacher?.IsActive == true && currentTeacher.TaskRole != null && currentTeacher.TaskRole.Contains("مشرف اختبارات"));

        if (!isGeneralSupervisor)
        {
            bool isCourseSupervisor = nomination.Course != null && (
                nomination.Course.ExamSupervisorId == currentUser.Id ||
                (currentUser.TeacherId.HasValue && nomination.Course.ExamSupervisorId == currentUser.TeacherId.Value)
            );

            if (!isCourseSupervisor)
            {
                return Forbid();
            }
        }

        nomination.Status = "Scheduled";
        nomination.ExamDate = dto.ExamDate;

        var student = nomination.Student;
        int? teacherId = nomination.Course?.TeacherId;
        if (!teacherId.HasValue && student?.CircleId.HasValue == true)
        {
            var circle = await _db.Circles.FindAsync(student.CircleId.Value);
            teacherId = circle?.TeacherId;
        }

        string examTypeName = nomination.NominationType == "Quran" ? "حفظ قرآن كريم" : $"دورة ({(nomination.Course != null ? nomination.Course.Name : "شرعية")})";
        string msgTitle = "إشعار موعد اختبار مجدول";
        string msgContent = $"تم تحديد وتأكيد موعد اختبار {examTypeName} للطالب ({student?.FullName}) بتاريخ: {dto.ExamDate}.";

        // Single targeted announcement to Student (covers Student & Parent without duplicates)
        if (student != null)
        {
            _db.Announcements.Add(new Announcement { Title = msgTitle, Content = msgContent, TargetType = AnnouncementTarget.Student, TargetId = student.Id, DateTimeSent = DateTime.UtcNow, SenderName = "مشرف الاختبارات" });
        }
        if (teacherId.HasValue)
        {
            _db.Announcements.Add(new Announcement { Title = msgTitle, Content = msgContent, TargetType = AnnouncementTarget.Teacher, TargetId = teacherId.Value, DateTimeSent = DateTime.UtcNow, SenderName = "مشرف الاختبارات" });
        }

        await _db.SaveChangesAsync();

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
    [Idempotent]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.ExamSupervisor, UserRole.Teacher, UserRole.Parent)]
    public async Task<IActionResult> Evaluate([FromBody] EvaluateExamDto dto)
    {
        var nomination = await _db.ExamNominations
            .Include(n => n.Student)
            .Include(n => n.Course)
            .Include(n => n.Result)
            .FirstOrDefaultAsync(n => n.Id == dto.NominationId);

        if (nomination == null) return NotFound(new { Message = "طلب الترشيح غير موجود." });
        if (nomination.Status != "Scheduled") return BadRequest(new { Message = "يجب جدولة الاختبار قبل رصد النتيجة." });
        if (dto.Grade < 0 || dto.Grade > 100) return BadRequest(new { Message = "الدرجة يجب أن تكون بين صفر ومئة." });

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        var currentTeacher = currentUser.TeacherId.HasValue ? await _db.Teachers.FindAsync(currentUser.TeacherId.Value) : null;
        if ((currentUser.Role == UserRole.Parent || currentUser.Role == UserRole.Teacher) && currentTeacher?.IsActive != true) return Forbid();
        bool isGeneralSupervisor = currentUser.Role == UserRole.Admin ||
                                   currentUser.Role == UserRole.Developer ||
                                   currentUser.Role == UserRole.ExamSupervisor ||
                                   (currentTeacher?.IsActive == true && currentTeacher.TaskRole != null && currentTeacher.TaskRole.Contains("مشرف اختبارات"));

        if (!isGeneralSupervisor)
        {
            bool isCourseSupervisor = nomination.Course != null && (
                nomination.Course.ExamSupervisorId == currentUser.Id ||
                (currentUser.TeacherId.HasValue && nomination.Course.ExamSupervisorId == currentUser.TeacherId.Value)
            );

            if (!isCourseSupervisor)
            {
                return Forbid();
            }
        }

        if (!await QuranCircles.Api.Services.SensitiveActionVerifier.VerifyAsync(HttpContext, _db, dto.Code2FA))
            return BadRequest(new { error = "يرجى إدخال كلمة مرور حسابك الحالية لتأكيد اعتماد النتيجة." });

        if (nomination.Result == null)
        {
            nomination.Result = new ExamResult
            {
                ExamNominationId = nomination.Id,
                MajorMistakes = dto.MajorMistakes,
                MinorMistakes = dto.MinorMistakes,
                Grade = dto.Grade,
                Notes = dto.Notes,
                ExamDate = DateTime.UtcNow
            };
            _db.ExamResults.Add(nomination.Result);
        }
        else
        {
            nomination.Result.MajorMistakes = dto.MajorMistakes;
            nomination.Result.MinorMistakes = dto.MinorMistakes;
            nomination.Result.Grade = dto.Grade;
            nomination.Result.Notes = dto.Notes;
            nomination.Result.ExamDate = DateTime.UtcNow;
        }

        var settings = await _db.SystemSettings.FirstOrDefaultAsync() ?? new SystemSettings();
        int passingScore = settings.PassingScoreThreshold > 0 ? settings.PassingScoreThreshold : 70;

        nomination.Status = dto.Grade >= passingScore ? "Completed" : "Failed";

        // Sync with CourseEnrollment if this is a Course exam
        if (nomination.CourseId.HasValue)
        {
            var enrollment = await _db.CourseEnrollments
                .FirstOrDefaultAsync(e => e.CourseId == nomination.CourseId.Value && e.StudentId == nomination.StudentId);
            if (enrollment != null)
            {
                enrollment.Grade = dto.Grade;
                if (dto.Grade >= passingScore)
                {
                    enrollment.Status = "Passed";
                    if (string.IsNullOrEmpty(enrollment.CertificateCode))
                    {
                        enrollment.CertificateCode = $"CERT-{DateTime.Today.Year}{DateTime.Today.Month:00}-{new Random().Next(1000, 9999)}";
                        enrollment.CertificateDate = DateOnly.FromDateTime(DateTime.Today);
                    }
                }
                else
                {
                    enrollment.Status = "Failed";
                    enrollment.CertificateCode = null;
                    enrollment.CertificateDate = null;
                }
            }
        }

        var student = nomination.Student;
        int? teacherId = nomination.Course?.TeacherId;
        if (!teacherId.HasValue && student?.CircleId.HasValue == true)
        {
            var circle = await _db.Circles.FindAsync(student.CircleId.Value);
            teacherId = circle?.TeacherId;
        }

        string resultText = dto.Grade >= passingScore ? "مكتمـل واجتـاز بنجـاح" : "مكتمـل ولم يجتـز";
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

        await _db.SaveChangesAsync();

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

    [HttpGet("certificate/{id:int}/printable")]
    public async Task<IActionResult> GetPrintableCertificate(int id, [FromQuery] string? download)
    {
        var nomination = await _db.ExamNominations
            .Include(n => n.Student)
                .ThenInclude(s => s!.Circle)
                    .ThenInclude(c => c!.Teacher)
            .Include(n => n.Course)
                .ThenInclude(c => c!.Teacher)
            .Include(n => n.Result)
            .FirstOrDefaultAsync(n => n.Id == id);

        if (nomination == null || nomination.Result == null || nomination.Result.Grade < 60 || nomination.Status == "Failed")
        {
            return NotFound("<h1>عذراً، الشهادة غير موجودة أو لم يستوفِ الطالب شروط الاجتياز.</h1>");
        }

        if (nomination.NominationType != "Quran" && nomination.CourseId.HasValue)
        {
            var enrollment = await _db.CourseEnrollments.FirstOrDefaultAsync(e => e.CourseId == nomination.CourseId.Value && e.StudentId == nomination.StudentId);
            if (enrollment != null && (enrollment.Status == "Failed" || (enrollment.Grade.HasValue && enrollment.Grade.Value < 60)))
            {
                return NotFound("<h1>عذراً، الشهادة ملغاة أو لم يستوفِ الطالب شروط الاجتياز للمساق.</h1>");
            }
        }

        var isQuran = nomination.NominationType == "Quran";
        var studentName = nomination.Student?.FullName ?? "طالب المركز";
        var idNumber = nomination.Student?.StudentIdentityNumber ?? "غير مسجل";
        var code = isQuran ? $"QURAN-10{nomination.Id}" : $"CERT-CRS-{2000 + nomination.Id}";
        var grade = nomination.Result.Grade;
        var gradeText = grade >= 95 ? "ممتاز مرتفع" : (grade >= 90 ? "ممتاز" : (grade >= 80 ? "جيد جداً" : "جيد"));
        var examDate = nomination.Result.ExamDate.ToString("yyyy-MM-dd");

        string examSubject;
        if (isQuran)
        {
            if (nomination.JuzStart.HasValue && nomination.JuzEnd.HasValue)
            {
                examSubject = nomination.JuzStart.Value == 1 && nomination.JuzEnd.Value == 30
                    ? "القرآن الكريم كاملاً (30 جزءاً)"
                    : $"الأجزاء من الجزء ({nomination.JuzStart.Value}) إلى الجزء ({nomination.JuzEnd.Value})";
            }
            else
            {
                examSubject = "أجزاء من القرآن الكريم";
            }
        }
        else
        {
            examSubject = $"دورة ({nomination.Course?.Name ?? "العلوم الشرعية والتجويد"})";
        }

        var teacherName = isQuran
            ? (nomination.Student?.Circle?.Teacher?.FullName ?? "شيخ ومعلم الحلقة")
            : (nomination.Course?.Teacher?.FullName ?? "معلم ومحاضر الدورة");

        var autoDownloadScript = download == "pdf" ? @"
            setTimeout(function() {
                downloadPdf();
            }, 600);
        " : "";

        var html = $@"<!DOCTYPE html>
<html dir=""rtl"" lang=""ar"">
<head>
    <meta charset=""utf-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>شهادة اجتياز معتمدة - {studentName}</title>
    <link rel=""preconnect"" href=""https://fonts.googleapis.com"">
    <link rel=""preconnect"" href=""https://fonts.gstatic.com"" crossorigin>
    <link href=""https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800;900&display=swap"" rel=""stylesheet"">
    <link rel=""stylesheet"" href=""https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"">
    <script src=""https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js""></script>
    <script src=""https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js""></script>
    <style>
        @page {{
            size: A4 landscape;
            margin: 0;
        }}
        * {{
            box-sizing: border-box;
            -webkit-print-color-adjust: exact !important;
            print-color-adjust: exact !important;
        }}
        body {{
            margin: 0;
            padding: 0 0 24px 0;
            background: #0f172a;
            display: flex;
            flex-direction: column;
            align-items: center;
            font-family: 'Cairo', sans-serif;
            direction: rtl;
            min-height: 100vh;
        }}
        .action-bar {{
            position: sticky;
            top: 0;
            z-index: 9999;
            width: 100%;
            background: #1e293b;
            border-bottom: 2px solid #c5a059;
            padding: 12px 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            color: #fff;
            box-shadow: 0 4px 20px rgba(0,0,0,0.4);
            margin-bottom: 20px;
        }}
        .action-btn {{
            background: #0d5c3a;
            color: #fff;
            border: 1.5px solid #10b981;
            padding: 8px 20px;
            font-size: 13.5px;
            font-weight: bold;
            font-family: 'Cairo', sans-serif;
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.2s;
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }}
        .action-btn:hover {{
            background: #117a4d;
            transform: translateY(-1px);
        }}
        .action-btn.secondary {{
            background: #475569;
            border-color: #64748b;
        }}
        .action-btn.secondary:hover {{
            background: #64748b;
        }}
        .premium-certificate {{
            width: 297mm;
            height: 210mm;
            max-width: 297mm;
            max-height: 210mm;
            background: #ffffff;
            background-image:
                radial-gradient(circle at center, rgba(205, 162, 80, 0.05) 0%, transparent 70%),
                repeating-linear-gradient(45deg, rgba(205, 162, 80, 0.015) 0, rgba(205, 162, 80, 0.015) 1px, transparent 0, transparent 16px);
            box-sizing: border-box;
            padding: 10mm;
            position: relative;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.4);
            color: #1e293b;
            letter-spacing: 0 !important;
            overflow: hidden;
        }}
        .cert-outer-border {{
            border: 3.5px solid #c5a059;
            outline: 1.5px solid rgba(13, 92, 58, 0.45);
            outline-offset: -6px;
            height: 100%;
            box-sizing: border-box;
            padding: 5mm;
            position: relative;
            background: #fdfdfb;
        }}
        .cert-inner-border {{
            border: 1.5px solid rgba(197, 160, 89, 0.6);
            height: 100%;
            box-sizing: border-box;
            padding: 6mm 10mm;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            position: relative;
            background: radial-gradient(circle at center, #ffffff 40%, #fbfaf6 100%);
        }}
        .cert-corner {{
            position: absolute;
            width: 28px;
            height: 28px;
            border: 3px solid #c5a059;
            pointer-events: none;
        }}
        .cert-corner-tr {{ top: 4px; right: 4px; border-left: none; border-bottom: none; }}
        .cert-corner-tl {{ top: 4px; left: 4px; border-right: none; border-bottom: none; }}
        .cert-corner-br {{ bottom: 4px; right: 4px; border-left: none; border-top: none; }}
        .cert-corner-bl {{ bottom: 4px; left: 4px; border-right: none; border-top: none; }}

        .cert-header {{
            display: grid;
            grid-template-columns: 1fr auto 1fr;
            align-items: center;
            gap: 16px;
            border-bottom: 2px solid rgba(197, 160, 89, 0.35);
            padding-bottom: 6px;
        }}
        .cert-header-right {{ text-align: right; line-height: 1.35; }}
        .cert-state {{ font-size: 1.05rem; font-weight: 800; color: #0d5c3a; }}
        .cert-ministry {{ font-size: 0.82rem; color: #64748b; font-weight: 700; }}
        .cert-mosque {{ font-size: 0.95rem; font-weight: 800; color: #1e293b; }}

        .cert-header-center {{ text-align: center; display: flex; flex-direction: column; align-items: center; }}
        .cert-logo-container {{
            width: 135px;
            height: 135px;
            border-radius: 50%;
            padding: 5px;
            background: #ffffff;
            border: 3px solid #c5a059;
            box-shadow: 0 4px 14px rgba(197, 160, 89, 0.4);
            display: flex;
            align-items: center;
            justify-content: center;
        }}
        .cert-logo-img {{ width: 100%; height: 100%; object-fit: contain; border-radius: 50%; }}
        .cert-bismillah {{ font-size: 0.95rem; font-weight: 800; color: #c5a059; letter-spacing: 0 !important; margin-top: 4px; }}

        .cert-header-left {{ text-align: left; line-height: 1.35; }}
        .cert-center-title {{ font-size: 0.95rem; font-weight: 800; color: #0d5c3a; }}
        .cert-dept {{ font-size: 0.82rem; color: #64748b; font-weight: 700; }}
        .cert-serial-code {{ font-size: 0.82rem; color: #c5a059; font-weight: 700; }}
        .cert-serial-code code {{ background: rgba(197, 160, 89, 0.15); padding: 1px 6px; border-radius: 4px; font-family: monospace; font-size: 0.90rem; }}
        .cert-date-text {{ font-size: 0.82rem; color: #64748b; font-weight: 700; margin-top: 3px; }}

        .cert-title-section {{ text-align: center; margin: 6px 0 4px; }}
        .cert-title-badge {{
            display: inline-block;
            padding: 5px 32px;
            background: linear-gradient(135deg, #0d3b2e 0%, #15803d 50%, #0d3b2e 100%);
            color: #ffffff;
            border: 2px solid #c5a059;
            border-radius: 30px;
            font-size: 1.25rem;
            font-weight: 900;
            box-shadow: 0 4px 12px rgba(13, 92, 58, 0.3);
            letter-spacing: 0 !important;
        }}
        .cert-title-badge i {{ color: #ffd700; font-size: 1rem; margin: 0 8px; }}

        .cert-body {{ text-align: center; margin: 4px 0; }}
        .cert-preamble {{ font-size: 1rem; color: #475569; font-weight: 700; margin-bottom: 4px; }}
        .cert-student-box {{
            margin: 4px auto 6px;
            display: inline-block;
            padding: 3px 40px;
            background: rgba(205, 162, 80, 0.1);
            border-bottom: 3.5px solid #c5a059;
            border-radius: 8px 8px 0 0;
        }}
        .cert-student-name {{ font-size: 1.95rem; font-weight: 900; color: #0d3b2e; letter-spacing: 0 !important; }}
        .cert-statement {{ font-size: 1.05rem; line-height: 1.65; color: #334155; max-width: 90%; margin: 0 auto; font-weight: 600; }}
        .cert-grade-row {{ display: flex; justify-content: center; gap: 20px; margin-top: 8px; }}
        .cert-grade-pill {{ background: #f8fafc; border: 1.5px solid #cbd5e1; border-radius: 20px; padding: 3px 18px; font-size: 0.90rem; color: #1e293b; font-weight: 700; }}

        .cert-footer {{
            display: grid;
            grid-template-columns: 1fr auto 1fr;
            align-items: flex-end;
            gap: 20px;
            margin-top: 8px;
            padding-top: 8px;
            border-top: 1.5px solid rgba(197, 160, 89, 0.35);
        }}
        .cert-signature-box {{ text-align: center; }}
        .cert-signature-role {{ font-size: 0.90rem; font-weight: 800; color: #64748b; margin-bottom: 3px; }}
        .cert-signature-name {{ font-size: 1.15rem; font-weight: 900; color: #0d3b2e; }}
        .cert-signature-line {{ width: 160px; height: 2px; background: #c5a059; margin: 5px auto; }}
        .cert-signature-note {{ font-size: 0.78rem; color: #94a3b8; font-weight: 600; }}

        .cert-seal-box {{ text-align: center; display: flex; flex-direction: column; align-items: center; }}
        .cert-luxury-stamp {{
            width: 80px;
            height: 80px;
            background: radial-gradient(circle, #ffe28a 0%, #c5a059 70%, #9e782e 100%);
            border-radius: 50%;
            border: 3.5px double #ffffff;
            box-shadow: 0 4px 14px rgba(197, 160, 89, 0.5);
            display: flex;
            align-items: center;
            justify-content: center;
            color: #1e3328;
        }}
        .cert-stamp-ring {{ text-align: center; line-height: 1.15; }}
        .cert-stamp-star {{ font-size: 0.95rem; color: #0d3b2e; }}
        .cert-stamp-text {{ font-size: 0.72rem; font-weight: 900; color: #0d3b2e; }}
        .cert-stamp-center {{ font-size: 0.68rem; font-weight: 800; color: #1e293b; }}

        @media print {{
            body {{
                background: none !important;
                padding: 0 !important;
                margin: 0 !important;
            }}
            .action-bar {{
                display: none !important;
            }}
            .premium-certificate {{
                box-shadow: none !important;
                margin: 0 !important;
                width: 297mm !important;
                height: 210mm !important;
            }}
        }}
    </style>
</head>
<body>
    <div class=""action-bar"">
        <div style=""display:flex; align-items:center; gap:10px;"">
            <span style=""font-weight:bold; font-size:15px;"">📜 شهادة اجتياز معتمدة - {studentName}</span>
            <span style=""background:rgba(255,255,255,0.15); padding:2px 10px; border-radius:6px; font-size:12px; font-family:monospace;"">{code}</span>
        </div>
        <div style=""display:flex; gap:10px;"">
            <button class=""action-btn"" onclick=""downloadPdfDirect()"">
                <i class=""fa-solid fa-file-pdf""></i>
                <span>حفظ وتحميل بصيغة PDF 📥</span>
            </button>
            <button class=""action-btn secondary"" onclick=""window.print()"">
                <i class=""fa-solid fa-print""></i>
                <span>طباعة مباشرة 🖨️</span>
            </button>
        </div>
    </div>

    <div class=""premium-certificate"" id=""cert-root-target"">
        <div class=""cert-outer-border"">
            <div class=""cert-corner cert-corner-tr""></div>
            <div class=""cert-corner cert-corner-tl""></div>
            <div class=""cert-corner cert-corner-br""></div>
            <div class=""cert-corner cert-corner-bl""></div>

            <div class=""cert-inner-border"">
                <!-- Header -->
                <div class=""cert-header"">
                    <div class=""cert-header-right"">
                        <div class=""cert-state"">دَوْلَةُ فِلَسْطِين</div>
                        <div class=""cert-ministry"">دَارُ القُرْآنِ الكَرِيمِ وَالسُّنَّةِ</div>
                        <div class=""cert-mosque"">مَرْكَزُ البَيَانِ لِتَعْلِيمِ القُرْآنِ</div>
                    </div>

                    <div class=""cert-header-center"">
                        <div class=""cert-logo-container"">
                            <img src=""/assets/logo.png"" alt=""شعار المركز"" class=""cert-logo-img"" onerror=""this.src='/mobile/assets/logo.png'"">
                        </div>
                        <div class=""cert-bismillah"">بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ</div>
                    </div>

                    <div class=""cert-header-left"">
                        <div class=""cert-center-title"">إِدَارَةُ الشُّؤُونِ التَّعْلِيمِيَّةِ وَالاخْتِبَارَاتِ</div>
                        <div class=""cert-dept"">شَهَادَةُ اجْتِيَازٍ رَسْمِيَّةٌ مُعْتَمَدَةٌ</div>
                        <div class=""cert-serial-code"">الرَّقْمُ المُعْتَمَدُ: <code>{code}</code></div>
                        <div class=""cert-date-text"">تَارِيخُ الإِصْدَارِ: {examDate}</div>
                    </div>
                </div>

                <!-- Title Section -->
                <div class=""cert-title-section"">
                    <div class=""cert-title-badge"">
                        <i class=""fa-solid fa-award""></i>
                        <span>{(isQuran ? "شَهَادَةُ اجْتِيَازِ اخْتِبَارِ القُرْآنِ الكَرِيمِ" : "شَهَادَةُ إِتْمَامِ دَوْرَةٍ عِلْمِيَّةٍ مُعْتَمَدَةٍ")}</span>
                        <i class=""fa-solid fa-award""></i>
                    </div>
                </div>

                <!-- Body -->
                <div class=""cert-body"">
                    <div class=""cert-preamble"">
                        تَشْهَدُ إِدَارَةُ مَرْكَزِ البَيَانِ لِتَعْلِيمِ القُرْآنِ الكَرِيمِ بِأَنَّ الطَّالِبَ المُبَارَكَ:
                    </div>
                    <div class=""cert-student-box"">
                        <div class=""cert-student-name"">{studentName}</div>
                    </div>
                    <div class=""cert-statement"">
                        {(isQuran
                            ? $"قَدِ اجْتَازَ بِتَوْفِيقِ اللَّهِ تَعَالَى وَبِنَجَاحٍ اخْتِبَارَ حِفْظِ وَتَسْمِيعِ كِتَابِ اللَّهِ الكَرِيمِ <strong>{examSubject}</strong>، وَذَلِكَ بَعْدَ عَرْضِهِ شَفَوِيّاً عَلَى اللِّجَانِ المُخْتَصَّةِ بِالمَرْكَزِ، سَائِلِينَ اللَّهَ أَنْ يَجْعَلَهُ مِنْ أَهْلِ القُرْآنِ وَخَاصَّتِهِ."
                            : $"قَدْ أَكْمَلَ بِتَوْفِيقِ اللَّهِ تَعَالَى وَبِنَجَاحٍ كَافَّةَ مُتَطَلَّبَاتِ حُضُورِ وَاجْتِيَازِ <strong>{examSubject}</strong>، بِمَا يَتَضَمَّنُهُ المَنْهَجُ التَّأْهِيلِيُّ مِنْ تَطْبِيقَاتٍ وَاخْتِبَارَاتٍ مُعْتَمَدَةٍ، سَائِلِينَ المَوْلَى لَهُ دَوَامَ التَّوْفِيقِ وَالسَّدَادِ.")}
                    </div>

                    <div class=""cert-grade-row"">
                        <div class=""cert-grade-pill"">
                            <strong>التقدير العام:</strong> {gradeText}
                        </div>
                        <div class=""cert-grade-pill"">
                            <strong>الدرجة المستحقة:</strong> {grade}%
                        </div>
                        <div class=""cert-grade-pill"">
                            <strong>رقم الهوية:</strong> <span style=""font-family:monospace;"">{idNumber}</span>
                        </div>
                    </div>
                </div>

                <!-- Footer -->
                <div class=""cert-footer"">
                    <div class=""cert-signature-box"">
                        <div class=""cert-signature-role"">{(isQuran ? "المُحَفِّظُ وَمُعَلِّمُ الحَلَقَةِ" : "مُعَلِّمُ وَمُحَاضِرُ الدَّوْرَةِ")}</div>
                        <div class=""cert-signature-name"">{teacherName}</div>
                        <div class=""cert-signature-line""></div>
                        <div class=""cert-signature-note"">التوقيع والاعتماد الأكاديمي</div>
                    </div>

                    <div class=""cert-seal-box"">
                        <div class=""cert-luxury-stamp"">
                            <div class=""cert-stamp-ring"">
                                <div class=""cert-stamp-star"">★ ★ ★</div>
                                <div class=""cert-stamp-text"">مُجَازٌ رَسْمِيّاً</div>
                                <div class=""cert-stamp-center"">مَرْكَزُ البَيَانِ</div>
                            </div>
                        </div>
                    </div>

                    <div class=""cert-signature-box"">
                        <div class=""cert-signature-role"">أَمِيرُ المَرْكَزِ وَالمُشْرِفُ العَامُّ</div>
                        <div class=""cert-signature-name"">فضيلة الشيخ / علي حسن النبيه</div>
                        <div class=""cert-signature-line""></div>
                        <div class=""cert-signature-note"">ختم واعتماد الإدارة العامة</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        async function downloadPdfDirect() {{
            const el = document.getElementById('cert-root-target');
            try {{
                const canvas = await html2canvas(el, {{
                    scale: 2.5,
                    useCORS: true,
                    allowTaint: true,
                    backgroundColor: '#ffffff'
                }});
                const imgData = canvas.toDataURL('image/jpeg', 0.98);
                const {{ jsPDF }} = window.jspdf;
                const pdf = new jsPDF({{
                    orientation: 'landscape',
                    unit: 'mm',
                    format: 'a4'
                }});
                pdf.addImage(imgData, 'JPEG', 0, 0, 297, 210);
                pdf.save('شهادة_{studentName.Replace(" ", "_")}.pdf');
            }} catch(err) {{
                window.print();
            }}
        }}
        {autoDownloadScript}
    </script>
</body>
</html>";

        return Content(html, "text/html", System.Text.Encoding.UTF8);
    }
}
