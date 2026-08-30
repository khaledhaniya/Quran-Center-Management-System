using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CoursesController : ControllerBase
{
    private readonly AppDbContext _db;

    public CoursesController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);

        var query = _db.Courses.AsQueryable();

        if (currentUser != null && currentUser.Role == UserRole.Teacher)
        {
            query = query.Where(c => c.TeacherId == currentUser.TeacherId);
        }

        var courses = await query
            .Include(c => c.Teacher)
            .Include(c => c.ExamSupervisor)
            .Select(c => new
            {
                c.Id,
                c.Name,
                c.Description,
                c.TeacherId,
                TeacherName = c.Teacher != null ? c.Teacher.FullName : "بدون معلم",
                c.ExamSupervisorId,
                ExamSupervisorName = c.ExamSupervisor != null ? c.ExamSupervisor.FullName : "بدون مشرف",
                c.IsActive,
                EnrollmentCount = c.Enrollments.Count
            })
            .ToListAsync();

        return Ok(courses);
    }

    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Create([FromBody] CreateCourseDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { Message = "اسم الدورة مطلوب." });

        var course = new Course
        {
            Name = dto.Name,
            Description = dto.Description ?? string.Empty,
            TeacherId = dto.TeacherId,
            ExamSupervisorId = dto.ExamSupervisorId,
            IsActive = true
        };

        _db.Courses.Add(course);
        await _db.SaveChangesAsync();

        // Audit Log
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        _db.AuditLogs.Add(new AuditLog
        {
            Username = currentUser?.Username ?? "Unknown",
            Action = "CreateCourse",
            Details = $"إنشاء الدورة الجديدة: {course.Name}",
            Timestamp = DateTime.UtcNow,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
        });
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetAll), new { id = course.Id }, course);
    }

    [HttpPut("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Update(int id, [FromBody] CreateCourseDto dto)
    {
        var course = await _db.Courses.FindAsync(id);
        if (course == null) return NotFound(new { Message = "الدورة غير موجودة." });

        if (string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { Message = "اسم الدورة مطلوب." });

        course.Name = dto.Name;
        course.Description = dto.Description ?? string.Empty;
        course.TeacherId = dto.TeacherId;
        course.ExamSupervisorId = dto.ExamSupervisorId;

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        _db.AuditLogs.Add(new AuditLog
        {
            Username = currentUser?.Username ?? "Unknown",
            Action = "UpdateCourse",
            Details = $"تعديل الدورة الأكاديمية والمشرف والمعلم: {course.Name} (ID: {course.Id})",
            Timestamp = DateTime.UtcNow,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
        });

        await _db.SaveChangesAsync();
        return Ok(new { Message = "تم تحديث بيانات الدورة والمشرف بنجاح.", Course = course });
    }

    [HttpDelete("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Delete(int id)
    {
        var course = await _db.Courses
            .Include(c => c.Enrollments)
            .FirstOrDefaultAsync(c => c.Id == id);

        if (course == null) return NotFound(new { Message = "الدورة غير موجودة." });

        var attendances = await _db.CourseAttendances.Where(ca => ca.CourseId == id).ToListAsync();
        _db.CourseAttendances.RemoveRange(attendances);
        _db.CourseEnrollments.RemoveRange(course.Enrollments);
        _db.Courses.Remove(course);

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        _db.AuditLogs.Add(new AuditLog
        {
            Username = currentUser?.Username ?? "Unknown",
            Action = "DeleteCourse",
            Details = $"حذف الدورة الأكاديمية: {course.Name} (ID: {course.Id})",
            Timestamp = DateTime.UtcNow,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
        });

        await _db.SaveChangesAsync();
        return Ok(new { Message = "تم حذف الدورة الأكاديمية وجميع سجلاتها بنجاح." });
    }

    [HttpPost("enroll")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> Enroll([FromBody] EnrollDto dto)
    {
        var course = await _db.Courses.FindAsync(dto.CourseId);
        if (course == null) return NotFound(new { Message = "الدورة غير موجودة." });

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        if (currentUser.Role == UserRole.Teacher)
        {
            // 1. Must be the instructor of this course
            if (course.TeacherId != currentUser.TeacherId)
            {
                return Forbid();
            }

            // 2. If enrolling a circle, must own the circle
            if (dto.CircleId.HasValue)
            {
                var circle = await _db.Circles.FindAsync(dto.CircleId.Value);
                if (circle == null || circle.TeacherId != currentUser.TeacherId)
                {
                    return Forbid();
                }
            }

            // 3. If enrolling a student, student must be in their circle
            if (dto.StudentId.HasValue)
            {
                var student = await _db.Students.FindAsync(dto.StudentId.Value);
                if (student == null || !student.CircleId.HasValue)
                {
                    return Forbid();
                }
                var circle = await _db.Circles.FindAsync(student.CircleId.Value);
                if (circle == null || circle.TeacherId != currentUser.TeacherId)
                {
                    return Forbid();
                }
            }
        }

        var enrolledStudentIds = new List<int>();

        if (dto.CircleId.HasValue)
        {
            // تسجيل حلقة كاملة
            var students = await _db.Students
                .Where(s => s.CircleId == dto.CircleId.Value && s.IsActive)
                .ToListAsync();

            foreach (var student in students)
            {
                var exists = await _db.CourseEnrollments
                    .AnyAsync(e => e.CourseId == dto.CourseId && e.StudentId == student.Id);

                if (!exists)
                {
                    _db.CourseEnrollments.Add(new CourseEnrollment
                    {
                        CourseId = dto.CourseId,
                        StudentId = student.Id,
                        Status = "Enrolled",
                        EnrollmentDate = DateOnly.FromDateTime(DateTime.Today)
                    });
                    enrolledStudentIds.Add(student.Id);
                }
            }
        }
        else if (dto.StudentId.HasValue)
        {
            // تسجيل طالب منفرد
            var student = await _db.Students.FindAsync(dto.StudentId.Value);
            if (student == null) return NotFound(new { Message = "الطالب غير موجود." });

            var exists = await _db.CourseEnrollments
                .AnyAsync(e => e.CourseId == dto.CourseId && e.StudentId == student.Id);

            if (!exists)
            {
                _db.CourseEnrollments.Add(new CourseEnrollment
                {
                    CourseId = dto.CourseId,
                    StudentId = student.Id,
                    Status = "Enrolled",
                    EnrollmentDate = DateOnly.FromDateTime(DateTime.Today)
                });
                enrolledStudentIds.Add(student.Id);
            }
            else
            {
                return BadRequest(new { Message = "الطالب مسجل بالفعل في هذه الدورة." });
            }
        }
        else
        {
            return BadRequest(new { Message = "يجب تحديد حلقة أو طالب للتسجيل." });
        }

        await _db.SaveChangesAsync();

        // Audit Log
        _db.AuditLogs.Add(new AuditLog
        {
            Username = currentUser?.Username ?? "Unknown",
            Action = "EnrollStudents",
            Details = $"تسجيل {enrolledStudentIds.Count} طالب في الدورة: {course.Name}",
            Timestamp = DateTime.UtcNow,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
        });
        await _db.SaveChangesAsync();

        return Ok(new { Message = "تم تسجيل الطلاب بنجاح.", EnrolledCount = enrolledStudentIds.Count });
    }

    [HttpGet("my-courses")]
    public async Task<IActionResult> GetMyCourses()
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        List<int> studentIds = new List<int>();

        if (currentUser.Role == UserRole.Student)
        {
            if (currentUser.StudentId.HasValue)
                studentIds.Add(currentUser.StudentId.Value);
        }
        else if (currentUser.Role == UserRole.Parent)
        {
            if (currentUser.ParentId.HasValue)
            {
                studentIds = await _db.Students
                    .Where(s => s.ParentId == currentUser.ParentId.Value)
                    .Select(s => s.Id)
                    .ToListAsync();
            }
        }
        else
        {
            // Admins/Developers/Teachers: Return passed/certified enrollments
            var query = _db.CourseEnrollments.AsQueryable();

            if (currentUser.Role == UserRole.Teacher)
            {
                query = query.Where(e => e.Student != null && e.Student.Circle != null && e.Student.Circle.TeacherId == currentUser.TeacherId);
            }

            var allEnrollments = await query
                .Include(e => e.Course)
                .ThenInclude(c => c!.Teacher)
                .Include(e => e.Student)
                .Where(e => e.Status == "Passed" || e.Status == "Certified")
                .Select(e => new
                {
                    e.Id,
                    e.CourseId,
                    CourseName = e.Course != null ? e.Course.Name : "",
                    CourseDescription = e.Course != null ? e.Course.Description : "",
                    TeacherName = (e.Course != null && e.Course.Teacher != null) ? e.Course.Teacher.FullName : "بدون معلم",
                    StudentName = e.Student != null ? e.Student.FullName : "",
                    e.Grade,
                    e.Status,
                    e.CertificateCode,
                    e.EnrollmentDate,
                    e.CertificateDate
                })
                .ToListAsync();

            return Ok(allEnrollments);
        }

        var enrollments = await _db.CourseEnrollments
            .Include(e => e.Course)
            .ThenInclude(c => c!.Teacher)
            .Include(e => e.Student)
            .Where(e => studentIds.Contains(e.StudentId))
            .Select(e => new
            {
                e.Id,
                e.CourseId,
                CourseName = e.Course != null ? e.Course.Name : "",
                CourseDescription = e.Course != null ? e.Course.Description : "",
                TeacherName = (e.Course != null && e.Course.Teacher != null) ? e.Course.Teacher.FullName : "بدون معلم",
                StudentName = e.Student != null ? e.Student.FullName : "",
                e.Grade,
                e.Status,
                e.CertificateCode,
                e.EnrollmentDate,
                e.CertificateDate
            })
            .ToListAsync();

        return Ok(enrollments);
    }

    [HttpGet("student/{studentId:int}")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> GetStudentEnrollments(int studentId)
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
        var enrollments = await _db.CourseEnrollments
            .Include(e => e.Course)
            .ThenInclude(c => c!.Teacher)
            .Where(e => e.StudentId == studentId)
            .Select(e => new
            {
                e.Id,
                e.CourseId,
                CourseName = e.Course != null ? e.Course.Name : "",
                CourseDescription = e.Course != null ? e.Course.Description : "",
                TeacherName = (e.Course != null && e.Course.Teacher != null) ? e.Course.Teacher.FullName : "بدون معلم",
                e.Grade,
                e.Status,
                e.CertificateCode,
                e.EnrollmentDate,
                e.CertificateDate
            })
            .ToListAsync();

        return Ok(enrollments);
    }

    [HttpGet("{id:int}/enrollments")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> GetEnrollments(int id)
    {
        var enrollments = await _db.CourseEnrollments
            .Include(e => e.Student)
            .ThenInclude(s => s!.Circle)
            .Where(e => e.CourseId == id)
            .Select(e => new
            {
                e.Id,
                e.StudentId,
                StudentName = e.Student != null ? e.Student.FullName : "",
                HalaqahName = (e.Student != null && e.Student.Circle != null) ? e.Student.Circle.Name : "بدون حلقة",
                e.Grade,
                e.Status,
                e.CertificateCode,
                e.EnrollmentDate,
                e.CertificateDate
            })
            .ToListAsync();

        return Ok(enrollments);
    }

    [HttpPut("grade")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> RecordGrade([FromBody] RecordGradeDto dto)
    {
        var enrollment = await _db.CourseEnrollments
            .Include(e => e.Course)
            .Include(e => e.Student)
            .FirstOrDefaultAsync(e => e.Id == dto.EnrollmentId);

        if (enrollment == null) return NotFound(new { Message = "سجل التسجيل غير موجود." });

        // RBAC validation: If teacher, make sure the student is in one of their circles
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        
        if (currentUser?.Role == UserRole.Teacher)
        {
            var teacherCircleIds = await _db.Circles
                .Where(c => c.TeacherId == currentUser.TeacherId)
                .Select(c => c.Id)
                .ToListAsync();

            if (!enrollment.Student!.CircleId.HasValue || !teacherCircleIds.Contains(enrollment.Student.CircleId.Value))
            {
                return Forbid();
            }
        }

        // 2FA Security check (simulated via header)
        var twoFactorHeader = Request.Headers["X-2FA-Code"].FirstOrDefault();
        bool twoFactorVerified = !string.IsNullOrWhiteSpace(twoFactorHeader) && twoFactorHeader == "123456";

        if (!twoFactorVerified)
        {
            return BadRequest(new { Message = "يرجى تأكيد الرمز الثنائي (2FA) لإتمام هذه العملية الحساسة.", Require2FA = true });
        }

        enrollment.Grade = dto.Grade;
        
        string oldStatus = enrollment.Status;
        if (dto.Grade >= 60)
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

        await _db.SaveChangesAsync();

        // Audit Log
        _db.AuditLogs.Add(new AuditLog
        {
            Username = currentUser?.Username ?? "Unknown",
            Action = "RecordCourseGrade",
            Details = $"رصد علامة الطالب {enrollment.Student?.FullName ?? "طالب"} في {enrollment.Course?.Name ?? "مساق"} بدرجة {dto.Grade} وحالة {enrollment.Status}",
            Timestamp = DateTime.UtcNow,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
        });
        await _db.SaveChangesAsync();

        // Trigger simulated WhatsApp alert if passed
        object? whatsappAlert = null;
        if (enrollment.Status == "Passed" && oldStatus != "Passed")
        {
            var message = $"مرحباً ولي أمر الطالب {enrollment.Student.FullName}، يسعدنا إعلامكم بنجاح ابنكم في {enrollment.Course.Name} بحصوله على درجة {dto.Grade}% وحصوله على شهادة رقمية معتمدة برمز: {enrollment.CertificateCode}. يمكنكم معاينتها من ملف الإنجاز الرقمي.";
            whatsappAlert = new
            {
                Recipient = enrollment.Student.FamilyContact,
                Message = message,
                SentSuccessfully = true,
                Timestamp = DateTime.Now
            };
        }

        return Ok(new
        {
            Message = "تم رصد العلامة وتحديث الحالة بنجاح.",
            Enrollment = new
            {
                enrollment.Id,
                enrollment.Grade,
                enrollment.Status,
                enrollment.CertificateCode,
                enrollment.CertificateDate
            },
            WhatsappAlert = whatsappAlert
        });
    }

    [HttpPost("attendance")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> RecordCourseAttendance([FromBody] BulkCourseAttendanceDto dto)
    {
        var course = await _db.Courses.FindAsync(dto.CourseId);
        if (course == null) return NotFound(new { Message = "الدورة غير موجودة." });

        if (dto.SessionDate > DateOnly.FromDateTime(DateTime.Today))
            return BadRequest(new { Message = "لا يمكن تسجيل حضور لتاريخ في المستقبل." });

        foreach (var item in dto.Items)
        {
            var existing = await _db.CourseAttendances
                .FirstOrDefaultAsync(ca => ca.CourseId == dto.CourseId && ca.StudentId == item.StudentId && ca.SessionDate == dto.SessionDate);

            if (existing != null)
            {
                existing.Status = item.Status;
            }
            else
            {
                var ca = new CourseAttendance
                {
                    CourseId = dto.CourseId,
                    StudentId = item.StudentId,
                    SessionDate = dto.SessionDate,
                    Status = item.Status
                };
                _db.CourseAttendances.Add(ca);
            }
        }

        await _db.SaveChangesAsync();
        return Ok(new { Message = "تم حفظ حضور وغياب المساق بنجاح." });
    }

    [HttpGet("{courseId:int}/attendance")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> GetCourseAttendance(int courseId, [FromQuery] DateOnly date)
    {
        var records = await _db.CourseAttendances
            .Where(ca => ca.CourseId == courseId && ca.SessionDate == date)
            .Select(ca => new {
                ca.StudentId,
                ca.Status
            })
            .ToListAsync();
        return Ok(records);
    }

    [HttpGet("student/{studentId:int}/attendance")]
    public async Task<IActionResult> GetStudentCourseAttendance(int studentId)
    {
        var history = await _db.CourseAttendances
            .Include(ca => ca.Course)
            .Where(ca => ca.StudentId == studentId)
            .OrderByDescending(ca => ca.SessionDate)
            .Select(ca => new {
                ca.Id,
                ca.CourseId,
                CourseName = ca.Course != null ? ca.Course.Name : "دورة محذوفة",
                ca.SessionDate,
                ca.Status,
                StatusText = ca.Status == AttendanceStatus.Present ? "حاضر" : (ca.Status == AttendanceStatus.Absent ? "غائب" : "متأخر")
            })
            .ToListAsync();
        return Ok(history);
    }
}

public record CreateCourseDto(string Name, string? Description, int? TeacherId, int? ExamSupervisorId);
public record EnrollDto(int CourseId, int? StudentId, int? CircleId);
public record RecordGradeDto(int EnrollmentId, double Grade);
public record BulkCourseAttendanceDto(int CourseId, DateOnly SessionDate, List<StudentAttendanceItemDto> Items);
public record StudentAttendanceItemDto(int StudentId, AttendanceStatus Status);
