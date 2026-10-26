using Microsoft.AspNetCore.Mvc;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

using Microsoft.EntityFrameworkCore;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/students")]
public class StudentsController : ControllerBase
{
    private readonly StudentService _svc;
    private readonly AppDbContext _db;
    private readonly PasswordHasher _hasher;
    private readonly ReportService _reportSvc;
    public StudentsController(StudentService svc, AppDbContext db, PasswordHasher hasher, ReportService reportSvc)
    {
        _svc = svc;
        _db = db;
        _hasher = hasher;
        _reportSvc = reportSvc;
    }

    [HttpGet("my-progress")]
    [RequireRole(UserRole.Student)]
    public async Task<IActionResult> GetMyProgress()
    {
        var userId = FakeAuth.GetUserId(HttpContext);
        if (!userId.HasValue) return Unauthorized(new { error = "جلسة غير صالحة." });

        var (progress, error) = await _svc.GetStudentProgressByUserIdAsync(userId.Value);
        if (error is not null) return BadRequest(new { error });

        return Ok(progress);
    }

    [HttpGet("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer, UserRole.Parent, UserRole.Student)]
    public async Task<IActionResult> Get(int id)
    {
        if (!await new StudentReadAccess(_db).CanReadAsync(HttpContext, id)) return Forbid();
        var hidePhone = FakeAuth.GetRole(HttpContext) == UserRole.Teacher &&
            await _db.SystemSettings.AsNoTracking().AnyAsync(x => x.HideParentPhoneFromTeacher);
        var s = await _svc.GetFullStudentByIdAsync(id, hidePhone);
        if (s == null) return NotFound(new { error = "الطالب غير موجود." });
        return Ok(s);
    }

    [HttpGet]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer, UserRole.Parent, UserRole.Student)]
    public async Task<IActionResult> GetAll([FromQuery] string? search, [FromQuery] bool? onlyCircle = null)
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser != null && currentUser.Role == UserRole.Parent)
        {
            if (currentUser.TeacherId.HasValue && await _db.Teachers.AnyAsync(t => t.Id == currentUser.TeacherId.Value && t.IsActive))
            {
                var hidePhone = await _db.SystemSettings.AsNoTracking().AnyAsync(x => x.HideParentPhoneFromTeacher);
                return Ok(await _svc.GetStudentsForTeacherAsync(currentUser.TeacherId.Value, search, onlyCircle == true, currentUserId, hidePhone));
            }
            var children = await _reportSvc.GetSmartChildrenForParentAsync(currentUser);
            return Ok(children.Select(s => StudentService.MapStudentToFullObject(s, currentUser?.FullName)).ToList());
        }
        else if (currentUser != null && currentUser.Role == UserRole.Student)
        {
            var myStudent = await _db.Students
                .Include(s => s.Circle)
                .Where(s => s.Id == currentUser.StudentId)
                .OrderBy(s => s.Id)
                .ToListAsync();
            return Ok(myStudent.Select(s => StudentService.MapStudentToFullObject(s)).ToList());
        }
        else if (currentUser != null && currentUser.Role == UserRole.Teacher)
        {
            if (!currentUser.TeacherId.HasValue || !await _db.Teachers.AnyAsync(t => t.Id == currentUser.TeacherId.Value && t.IsActive)) return Forbid();
            var hidePhone = await _db.SystemSettings.AsNoTracking().AnyAsync(x => x.HideParentPhoneFromTeacher);
            if (Request.Query.ContainsKey("all") || Request.Query["forEnrollment"] == "true")
            {
                return Ok(await _svc.GetAllAsync(search, hidePhone));
            }

            int teacherId = currentUser.TeacherId ?? 0;
            return Ok(await _svc.GetStudentsForTeacherAsync(teacherId, search, onlyCircle == true, currentUserId, hidePhone));
        }
        return Ok(await _svc.GetAllAsync(search));
    }

    [HttpGet("{id:int}/progress")]
    [HttpGet("{id:int}/360")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer, UserRole.Parent, UserRole.Student)]
    public async Task<IActionResult> GetProgress(int id)
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        var student = await _svc.GetByIdAsync(id);
        if (student == null) return NotFound(new { error = "الطالب غير موجود." });

        if (!await new StudentReadAccess(_db).CanReadAsync(HttpContext, id)) return Forbid();

        var (progress, error) = await _svc.GetStudentProgressByIdAsync(id);
        if (error is not null) return BadRequest(new { error });
        return Ok(progress);
    }



    [HttpGet("unassigned")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> GetUnassignedStudents()
    {
        var unassigned = await _db.Students
            .Include(s => s.Circle)
            .Where(s => s.CircleId == null && s.IsActive)
            .OrderBy(s => s.FullName)
            .ToListAsync();
        return Ok(unassigned.Select(s => StudentService.MapStudentToFullObject(s)).ToList());
    }

    [HttpGet("all-for-enrollment")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> GetAllForEnrollment([FromQuery] string? search)
    {
        var query = _db.Students.Include(s => s.Circle).ThenInclude(c => c!.Teacher).AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim().ToLower();
            query = query.Where(s => s.FullName.ToLower().Contains(q)
                || (s.StudentIdentityNumber != null && s.StudentIdentityNumber.Contains(q))
                || (s.FamilyContact != null && s.FamilyContact.Contains(q))
                || (s.StudentMobile != null && s.StudentMobile.Contains(q))
                || (s.Circle != null && s.Circle.Name.ToLower().Contains(q)));
        }
        var list = await query.OrderBy(s => s.FullName).ToListAsync();
        return Ok(list.Select(s => StudentService.MapStudentToFullObject(s)).ToList());
    }

    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> Create([FromBody] CreateStudentDto dto)
    {
        var settings = await _db.SystemSettings.FirstOrDefaultAsync() ?? new SystemSettings();
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);

        if (currentUser == null) return Unauthorized();
        if (currentUser.Role is not (UserRole.Admin or UserRole.Developer) && !settings.AllowTeacherSelfEnrollment)
        {
            return BadRequest(new { error = "عذراً، تسجيل وتنسيب الطلاب بواسطة المعلم معطل حالياً من قبل إدارة المركز." });
        }
        if (currentUser.Role is not (UserRole.Admin or UserRole.Developer))
        {
            var teacherId = currentUser.TeacherId;
            if (!teacherId.HasValue || !dto.CircleId.HasValue ||
                !await _db.Teachers.AnyAsync(t => t.Id == teacherId.Value && t.IsActive) ||
                !await _db.Circles.AnyAsync(c => c.Id == dto.CircleId.Value && c.IsActive &&
                    (c.TeacherId == teacherId.Value || c.AssistantTeacherId == teacherId.Value)))
                return Forbid();
        }

        var (created, createdParent, error) = await _svc.CreateAsync(dto);
        if (error is not null) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "CreateStudent", $"إضافة طالب جديد: {created!.FullName} - رقم الهوية: {created.StudentIdentityNumber}");

        return CreatedAtAction(nameof(Get), new { id = created!.Id }, new
        {
            student = created,
            createdParent = createdParent != null ? new
            {
                id = createdParent.Id,
                username = createdParent.Username,
                requiresPasswordSetup = true,
                fullName = createdParent.FullName
            } : null
        });
    }

    [HttpPut("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateStudentDto dto)
    {
        var settings = await _db.SystemSettings.FirstOrDefaultAsync() ?? new SystemSettings();
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);

        if (currentUser?.Role == UserRole.Teacher || (currentUser?.Role == UserRole.Parent && currentUser.TeacherId.HasValue))
        {
            var student = await _db.Students.Include(s => s.Circle).ThenInclude(c => c!.Teacher).FirstOrDefaultAsync(s => s.Id == id);
            if (student == null) return NotFound(new { error = "الطالب غير موجود." });

            int tId = currentUser.TeacherId ?? 0;
            var teacherObj = tId > 0 ? await _db.Teachers.FindAsync(tId) : null;

            bool isHisStudent = teacherObj?.IsActive == true && student.CircleId.HasValue &&
                (student.Circle?.TeacherId == tId || student.Circle?.AssistantTeacherId == tId);
            bool targetAssigned = !dto.CircleId.HasValue || await _db.Circles.AnyAsync(c => c.Id == dto.CircleId.Value && c.IsActive &&
                (c.TeacherId == tId || c.AssistantTeacherId == tId));
            if (!isHisStudent || !targetAssigned)
            {
                return Forbid();
            }
        }

        var (ok, error) = await _svc.UpdateAsync(id, dto);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "UpdateStudent", $"تعديل بيانات الطالب: {dto.FullName} (ID: #{id})");

        return NoContent();
    }

    [HttpDelete("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Deactivate(int id)
    {
        var ok = await _svc.DeactivateAsync(id);
        if (ok)
        {
            await AuditLogger.LogAsync(_db, HttpContext, "DeactivateStudent", $"تعطيل حساب الطالب ID: #{id}");
        }
        return ok ? NoContent() : NotFound(new { error = "الطالب غير موجود." });
    }

    [HttpDelete("{id:int}/permanent")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> HardDelete(int id)
    {
        var (ok, studentName, error) = await _svc.HardDeleteAsync(id);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "HardDeleteStudent", $"حذف نهائي للطالب: {studentName} (ID: #{id}) وكافة سجلاته وحسابه");

        return Ok(new { Message = $"تم حذف الطالب ({studentName}) وحساباته وسجلاته نهائياً من المنظومة." });
    }

    [HttpPost("{id:int}/toggle-active")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> ToggleActive(int id)
    {
        var (ok, newStatus, error) = await _svc.ToggleActiveAsync(id);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "ToggleActiveStudent", $"تغيير حالة تفعيل الطالب ID #{id} إلى: {(newStatus ? "نشط" : "معطل")}");

        return Ok(new { Message = newStatus ? "تم تنشيط الطالب بنجاح." : "تم تعطيل الطالب بنجاح.", IsActive = newStatus });
    }

    [HttpPut("{id:int}/plan")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> UpdatePlan(int id, [FromBody] UpdateStudentPlanDto dto)
    {
        var student = await _db.Students.Include(s => s.Circle).ThenInclude(c => c!.Teacher).FirstOrDefaultAsync(s => s.Id == id);
        if (student == null) return NotFound(new { error = "الطالب غير موجود." });

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser?.Role == UserRole.Teacher)
        {
            if (await _db.SystemSettings.AsNoTracking().AnyAsync(s => !s.AllowTeacherEditStudentPlan))
                return Forbid();
            int tId = currentUser.TeacherId ?? 0;
            Teacher? teacherObj = null;
            if (tId > 0)
            {
                teacherObj = await _db.Teachers.FindAsync(tId);
            }
            if (teacherObj == null)
            {
                teacherObj = await _db.Teachers.FirstOrDefaultAsync(x => x.FullName == currentUser.FullName);
                if (teacherObj != null) tId = teacherObj.Id;
            }

            var taskRole = teacherObj?.TaskRole ?? "";
            bool isSupervisorOrAdmin = taskRole.Contains("مشرف") || taskRole.Contains("موجه") || currentUser.Role == UserRole.Admin || currentUser.Role == UserRole.Developer;

            bool isHisStudent = false;
            if (student.CircleId.HasValue)
            {
                var teacherCircleIds = await _db.Circles
                    .Where(c => c.TeacherId == tId || (teacherObj != null && c.TeacherId == teacherObj.Id) || (c.Teacher != null && c.Teacher.FullName == currentUser.FullName))
                    .Select(c => c.Id)
                    .ToListAsync();
                isHisStudent = teacherCircleIds.Contains(student.CircleId.Value);
            }

            if (!isHisStudent && !isSupervisorOrAdmin)
            {
                return Forbid();
            }
        }

        student.TargetAjzaaCount = dto.TargetAjzaaCount > 0 ? dto.TargetAjzaaCount : 30;
        student.PlanType = dto.PlanType ?? "Standard";
        if (dto.PlanStartDate.HasValue) student.PlanStartDate = dto.PlanStartDate.Value;
        student.PlanTargetDate = dto.PlanTargetDate;
        student.DailyPacePages = dto.DailyPacePages > 0 ? dto.DailyPacePages : 1.0;
        if (dto.CompletedAjzaa != null) student.CompletedAjzaa = dto.CompletedAjzaa;
        if (dto.PreviousQuranMemorization != null) student.PreviousQuranMemorization = dto.PreviousQuranMemorization;
        if (dto.PlanNotes != null) student.PlanNotes = dto.PlanNotes;
        else if (dto.Notes != null && student.PlanNotes == null) student.PlanNotes = dto.Notes;

        await _db.SaveChangesAsync();
        await AuditLogger.LogAsync(_db, HttpContext, "UpdateStudentPlan", $"تحديث خطة حفظ الطالب: {student.FullName} (نوع الخطة: {student.PlanType}، المستهدف: {student.TargetAjzaaCount} أجزاء)");

        return Ok(new
        {
            Message = "تم حفظ خطة الحفظ للطالب بنجاح.",
            StudentId = student.Id,
            PlanType = student.PlanType,
            TargetAjzaaCount = student.TargetAjzaaCount,
            DailyPacePages = student.DailyPacePages,
            CompletedAjzaa = student.CompletedAjzaa,
            PreviousQuranMemorization = student.PreviousQuranMemorization,
            PlanNotes = student.PlanNotes
        });
    }

    [HttpPost("{id:int}/complete-juz")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> CompleteJuz(int id, [FromBody] CompleteJuzDto dto)
    {
        if(dto.JuzNumber < 1 || dto.JuzNumber > 30) return BadRequest(new { error = "رقم الجزء يجب أن يكون بين 1 و30." });
        var student = await _db.Students.Include(s => s.Circle).ThenInclude(c => c!.Teacher).FirstOrDefaultAsync(s => s.Id == id);
        if (student == null) return NotFound(new { error = "الطالب غير موجود." });

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser?.Role == UserRole.Teacher)
        {
            if (await _db.SystemSettings.AsNoTracking().AnyAsync(s => !s.AllowTeacherEditStudentPlan))
                return Forbid();
            int tId = currentUser.TeacherId ?? 0;
            Teacher? teacherObj = null;
            if (tId > 0)
            {
                teacherObj = await _db.Teachers.FindAsync(tId);
            }
            if (teacherObj == null)
            {
                teacherObj = await _db.Teachers.FirstOrDefaultAsync(x => x.FullName == currentUser.FullName);
                if (teacherObj != null) tId = teacherObj.Id;
            }

            bool isHisStudent = student.CircleId.HasValue && (student.Circle?.TeacherId == tId || (student.Circle?.Teacher != null && student.Circle.Teacher.FullName == currentUser.FullName));
            var taskRole = teacherObj?.TaskRole ?? "";
            bool isSupervisorOrAdmin = taskRole.Contains("مشرف") || taskRole.Contains("موجه") || currentUser.Role == UserRole.Admin || currentUser.Role == UserRole.Developer;

            if (!isHisStudent && !isSupervisorOrAdmin)
            {
                return Forbid();
            }
        }

        var completedSet = new HashSet<int>();
        if (!string.IsNullOrWhiteSpace(student.CompletedAjzaa))
        {
            foreach (var part in student.CompletedAjzaa.Split(new[] { ',', ' ' }, StringSplitOptions.RemoveEmptyEntries))
            {
                if (int.TryParse(part, out int j)) completedSet.Add(j);
            }
        }

        if (dto.IsCompleted)
        {
            completedSet.Add(dto.JuzNumber);
        }
        else
        {
            completedSet.Remove(dto.JuzNumber);
        }

        student.CompletedAjzaa = string.Join(",", completedSet.OrderBy(x => x));
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "CompleteJuz", $"{(dto.IsCompleted ? "توثيق إتمام" : "إلغاء إتمام")} الجزء {dto.JuzNumber} للطالب: {student.FullName}");

        return Ok(new { Message = "تم تحديث سجل الأجزاء المنجزة بنجاح.", CompletedAjzaa = student.CompletedAjzaa, CompletedCount = completedSet.Count });
    }
}

public record UpdateStudentPlanDto(
    int TargetAjzaaCount,
    string? PlanType,
    DateOnly? PlanStartDate,
    DateOnly? PlanTargetDate,
    double DailyPacePages,
    string? CompletedAjzaa,
    string? PreviousQuranMemorization = null,
    string? PlanNotes = null,
    string? Notes = null
);

public record CompleteJuzDto(int JuzNumber, bool IsCompleted);

