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
                ExamSupervisorTeacherId = c.ExamSupervisor != null ? c.ExamSupervisor.TeacherId : null,
                ExamSupervisorName = c.ExamSupervisor != null 
                    ? c.ExamSupervisor.FullName 
                    : (c.ExamSupervisorId != null && _db.Teachers.Any(t => t.Id == c.ExamSupervisorId)
                        ? _db.Teachers.First(t => t.Id == c.ExamSupervisorId).FullName
                        : "بدون مشرف"),
                c.IsActive,
                EnrollmentCount = c.Enrollments.Count
            })
            .ToListAsync();

        return Ok(courses);
    }

    [HttpGet("comprehensive-report")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> GetComprehensiveReport()
    {
        var courses = await _db.Courses
            .Include(c => c.Teacher)
            .Include(c => c.ExamSupervisor)
            .Include(c => c.Enrollments)
                .ThenInclude(e => e.Student)
                    .ThenInclude(s => s!.Circle)
            .ToListAsync();

        var courseIds = courses.Select(c => c.Id).ToList();

        // Get all nominations for these courses
        var nominations = await _db.ExamNominations
            .Include(n => n.Result)
            .Where(n => n.CourseId.HasValue && courseIds.Contains(n.CourseId.Value))
            .ToListAsync();

        // Get all attendance records for these courses
        var attendances = await _db.CourseAttendances
            .Where(ca => courseIds.Contains(ca.CourseId))
            .ToListAsync();

        var report = courses.Select(c =>
        {
            var cSupervisorName = c.ExamSupervisor != null
                ? c.ExamSupervisor.FullName
                : (c.ExamSupervisorId != null && _db.Teachers.Any(t => t.Id == c.ExamSupervisorId)
                    ? _db.Teachers.First(t => t.Id == c.ExamSupervisorId).FullName
                    : "بدون مشرف");

            var courseNoms = nominations.Where(n => n.CourseId == c.Id).ToList();
            var courseAtts = attendances.Where(ca => ca.CourseId == c.Id).ToList();

            var studentRows = c.Enrollments.Select(e =>
            {
                var st = e.Student;
                var nom = courseNoms.FirstOrDefault(n => n.StudentId == e.StudentId);
                var stAtts = courseAtts.Where(ca => ca.StudentId == e.StudentId).ToList();
                int presentCount = stAtts.Count(a => a.Status == AttendanceStatus.Present);
                int absentCount = stAtts.Count(a => a.Status == AttendanceStatus.Absent);
                int lateCount = stAtts.Count(a => a.Status == AttendanceStatus.Late);

                string statusDesc = e.Status switch
                {
                    "Passed" => "ناجح",
                    "Failed" => "راسب",
                    "Certified" => "مجاز بشهادة",
                    _ => "قيد الدراسة"
                };

                string evaluation = "";
                if (e.Grade.HasValue)
                {
                    double g = e.Grade.Value;
                    if (g >= 90) evaluation = "ممتاز";
                    else if (g >= 80) evaluation = "جيد جداً";
                    else if (g >= 70) evaluation = "جيد";
                    else if (g >= 60) evaluation = "مقبول";
                    else evaluation = "راسب";
                }

                return new
                {
                    EnrollmentId = e.Id,
                    StudentId = e.StudentId,
                    StudentName = st != null ? st.FullName : "طالب غير معروف",
                    StudentIdentityNumber = st?.StudentIdentityNumber ?? "-",
                    StudentMobile = st?.StudentMobile ?? st?.FamilyContact ?? "-",
                    CircleName = st?.Circle != null ? st.Circle.Name : "بدون حلقة",
                    EnrollmentDate = e.EnrollmentDate.ToString("yyyy-MM-dd"),
                    Status = e.Status,
                    StatusArabic = statusDesc,
                    Grade = e.Grade,
                    Evaluation = evaluation,
                    CertificateCode = e.CertificateCode ?? "-",
                    CertificateDate = e.CertificateDate?.ToString("yyyy-MM-dd") ?? "-",
                    ExamScheduledDate = nom?.ExamDate?.ToString("yyyy-MM-dd HH:mm") ?? "-",
                    ExamStatus = nom != null ? (nom.Status switch { "Completed" => "مكتمل", "Scheduled" => "مجدول", "Cancelled" => "ملغي", _ => "قيد الانتظار" }) : "-",
                    ExamScore = nom?.Result?.Grade,
                    ExamNotes = nom?.Result?.Notes ?? "-",
                    PresentDays = presentCount,
                    AbsentDays = absentCount,
                    LateDays = lateCount,
                    TotalCourseDays = stAtts.Count
                };
            }).OrderBy(x => x.StudentName).ToList();

            return new
            {
                CourseId = c.Id,
                CourseName = c.Name,
                Description = c.Description,
                IsActive = c.IsActive,
                TeacherName = c.Teacher != null ? c.Teacher.FullName : "بدون معلم",
                TeacherMobile = c.Teacher != null ? (c.Teacher.WhatsappNumber ?? "-") : "-",
                ExamSupervisorName = cSupervisorName,
                TotalEnrolled = c.Enrollments.Count,
                TotalPassed = c.Enrollments.Count(e => e.Status == "Passed" || e.Status == "Certified"),
                TotalFailed = c.Enrollments.Count(e => e.Status == "Failed"),
                TotalPending = c.Enrollments.Count(e => e.Status != "Passed" && e.Status != "Certified" && e.Status != "Failed"),
                Students = studentRows
            };
        }).OrderByDescending(c => c.CourseId).ToList();

        return Ok(new
        {
            CenterName = "مركز البيان القرآني",
            GeneratedAt = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss"),
            TotalCourses = report.Count,
            TotalStudentsEnrolled = report.Sum(r => r.TotalEnrolled),
            Courses = report
        });
    }

    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Create([FromBody] CreateCourseDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest(new { Message = "اسم الدورة مطلوب." });

        var trimmedName = dto.Name.Trim();

        // Idempotency: Prevent duplicate creation if a course with the same name is already active
        var existingCourse = await _db.Courses
            .FirstOrDefaultAsync(c => c.Name.Trim().ToLower() == trimmedName.ToLower() && c.IsActive);
        if (existingCourse != null)
        {
            return Ok(existingCourse);
        }

        int? resolvedSupervisorId = await ResolveSupervisorUserIdAsync(dto.ExamSupervisorId);

        var course = new Course
        {
            Name = trimmedName,
            Description = dto.Description ?? string.Empty,
            TeacherId = dto.TeacherId,
            ExamSupervisorId = resolvedSupervisorId,
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

        int? resolvedSupervisorId = await ResolveSupervisorUserIdAsync(dto.ExamSupervisorId);

        course.Name = dto.Name;
        course.Description = dto.Description ?? string.Empty;
        course.TeacherId = dto.TeacherId;
        course.ExamSupervisorId = resolvedSupervisorId;

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

    private async Task<int?> ResolveSupervisorUserIdAsync(int? supervisorInputId)
    {
        if (!supervisorInputId.HasValue || supervisorInputId.Value <= 0)
            return null;

        int id = supervisorInputId.Value;

        // 1. Is it an existing User Id?
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == id);
        if (user != null) return user.Id;

        // 2. Is it a Teacher Id that has a User account?
        var userByTeacher = await _db.Users.FirstOrDefaultAsync(u => u.TeacherId == id);
        if (userByTeacher != null) return userByTeacher.Id;

        // 3. Is it an existing Teacher? Create linked user account so FK constraint holds cleanly
        var teacher = await _db.Teachers.FindAsync(id);
        if (teacher != null)
        {
            var newUser = new User
            {
                Username = !string.IsNullOrWhiteSpace(teacher.IdentityNumber) ? teacher.IdentityNumber : $"teacher_{teacher.Id}",
                FullName = teacher.FullName,
                Role = UserRole.Teacher,
                TeacherId = teacher.Id,
                PasswordHash = "AQAAAAIAAYagAAAAEJrM9mFp9G1Gv8eO6Wl1k6Y1U2Z7Q8W9E0R1T2Y3U4I5O6P7A8S9D0F1G2H3J4K5L6",
                PlainPassword = "123",
                IsActive = true
            };
            _db.Users.Add(newUser);
            await _db.SaveChangesAsync();
            return newUser.Id;
        }

        return null;
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
                query = query.Where(e => 
                    (e.Student != null && e.Student.Circle != null && e.Student.Circle.TeacherId == currentUser.TeacherId) ||
                    (e.Course != null && e.Course.TeacherId == currentUser.TeacherId) ||
                    (e.Course != null && (e.Course.ExamSupervisorId == currentUser.Id || (currentUser.TeacherId.HasValue && e.Course.ExamSupervisorId == currentUser.TeacherId.Value)))
                );
            }

            var allEnrollments = await query
                .Include(e => e.Course)
                .ThenInclude(c => c!.Teacher)
                .Include(e => e.Student)
                .Where(e => e.Status == "Passed" || e.Status == "Certified")
                .Select(e => new
                {
                    e.Id,
                    e.StudentId,
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
                e.StudentId,
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
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer, UserRole.ExamSupervisor)]
    public async Task<IActionResult> RecordGrade([FromBody] RecordGradeDto dto)
    {
        var enrollment = await _db.CourseEnrollments
            .Include(e => e.Course)
            .Include(e => e.Student)
            .FirstOrDefaultAsync(e => e.Id == dto.EnrollmentId);

        if (enrollment == null) return NotFound(new { Message = "سجل التسجيل غير موجود." });

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        // RBAC validation: Allow Admin, Developer, ExamSupervisor.
        // If Teacher: Allow if course teacher, course supervisor, exam specialist, or circle teacher.
        if (currentUser.Role == UserRole.Teacher)
        {
            var teacher = currentUser.TeacherId.HasValue ? await _db.Teachers.FindAsync(currentUser.TeacherId.Value) : null;
            bool isExamSpecialist = teacher?.TaskRole != null && teacher.TaskRole.Contains("مشرف اختبارات");

            bool isCourseTeacher = enrollment.Course != null && enrollment.Course.TeacherId == currentUser.TeacherId;
            bool isCourseSupervisor = enrollment.Course != null && (
                enrollment.Course.ExamSupervisorId == currentUser.Id ||
                (currentUser.TeacherId.HasValue && enrollment.Course.ExamSupervisorId == currentUser.TeacherId.Value)
            );

            bool isCircleTeacher = false;
            if (enrollment.Student?.CircleId.HasValue == true)
            {
                isCircleTeacher = await _db.Circles.AnyAsync(c => c.Id == enrollment.Student.CircleId.Value && c.TeacherId == currentUser.TeacherId);
            }

            if (!isExamSpecialist && !isCourseTeacher && !isCourseSupervisor && !isCircleTeacher)
            {
                return Forbid();
            }
        }

        // 2FA Security check (simulated via header or DTO)
        var twoFactorHeader = Request.Headers["X-2FA-Code"].FirstOrDefault() ?? dto.Code2FA;
        if (!string.IsNullOrWhiteSpace(twoFactorHeader) && twoFactorHeader != "123456")
        {
            return BadRequest(new { Message = "رمز التحقق الثنائي (2FA) غير صحيح. رمز التوجيه هو: 123456", Require2FA = true });
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
public record RecordGradeDto(int EnrollmentId, double Grade, string? Code2FA = null);
public record BulkCourseAttendanceDto(int CourseId, DateOnly SessionDate, List<StudentAttendanceItemDto> Items);
public record StudentAttendanceItemDto(int StudentId, AttendanceStatus Status);
