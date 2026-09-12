using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/huffaz")]
public class HuffazForumController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly PasswordHasher _hasher;

    public HuffazForumController(AppDbContext db, PasswordHasher hasher)
    {
        _db = db;
        _hasher = hasher;
    }

    [HttpGet]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.ExamSupervisor)]
    public async Task<IActionResult> GetAll([FromQuery] string? filter)
    {
        var query = _db.HuffazMembers
            .Include(h => h.Teacher)
            .Include(h => h.Student)
                .ThenInclude(s => s!.Circle)
            .Include(h => h.SupervisorTeacher)
            .AsNoTracking()
            .AsQueryable();

        if (filter == "khatim") query = query.Where(h => h.IsKhatim || h.MemorizedAjzaaCount >= 30);
        else if (filter == "teachers") query = query.Where(h => h.MemberType == "Teacher");
        else if (filter == "students") query = query.Where(h => h.MemberType == "Student");
        else if (filter == "external") query = query.Where(h => h.MemberType == "External");

        var list = await query
            .OrderByDescending(h => h.MemorizedAjzaaCount)
            .ThenByDescending(h => h.Id)
            .Select(h => new
            {
                h.Id,
                h.MemberType,
                MemberTypeText = h.MemberType == "Teacher" ? "معلم بالمركز 👨‍🏫" : (h.MemberType == "Student" ? "طالب بالمركز 🎓" : "حافظ خارجي 🌐"),
                h.TeacherId,
                h.StudentId,
                FullName = h.MemberType == "Teacher" && h.Teacher != null ? h.Teacher.FullName :
                           (h.MemberType == "Student" && h.Student != null ? h.Student.FullName : h.FullName),
                IdentityNumber = h.IdentityNumber ?? (h.MemberType == "Teacher" ? h.Teacher!.IdentityNumber : (h.MemberType == "Student" ? h.Student!.StudentIdentityNumber : null)),
                PhoneNumber = h.PhoneNumber ?? (h.MemberType == "Teacher" ? h.Teacher!.Contact : (h.MemberType == "Student" ? h.Student!.StudentMobile : null)),
                CircleName = h.Student != null && h.Student.Circle != null ? h.Student.Circle.Name : (h.MemberType == "Teacher" ? "كادر المشايخ" : "خارج المركز"),
                h.MemorizedAjzaaCount,
                h.IsKhatim,
                h.Riwayah,
                h.SupervisorTeacherId,
                SupervisorTeacherName = h.SupervisorTeacher != null ? h.SupervisorTeacher.FullName : "غير معين",
                h.RevisionPlan,
                h.Notes,
                JoinDate = h.JoinDate.ToString("yyyy-MM-dd"),
                h.IsActive,
                h.CreatedAt
            })
            .ToListAsync();

        // Calculate Stats
        var allMembers = await _db.HuffazMembers.AsNoTracking().ToListAsync();
        int totalMembers = allMembers.Count;
        int khatimsCount = allMembers.Count(m => m.IsKhatim || m.MemorizedAjzaaCount >= 30);
        int plus20Count = allMembers.Count(m => m.MemorizedAjzaaCount >= 20 && m.MemorizedAjzaaCount < 30 && !m.IsKhatim);
        int plus10Count = allMembers.Count(m => m.MemorizedAjzaaCount >= 10 && m.MemorizedAjzaaCount < 20);
        int teachersCount = allMembers.Count(m => m.MemberType == "Teacher");
        int studentsCount = allMembers.Count(m => m.MemberType == "Student");
        int externalCount = allMembers.Count(m => m.MemberType == "External");

        return Ok(new
        {
            Members = list,
            Stats = new
            {
                TotalMembers = totalMembers,
                KhatimsCount = khatimsCount,
                Plus20Count = plus20Count,
                Plus10Count = plus10Count,
                TeachersCount = teachersCount,
                StudentsCount = studentsCount,
                ExternalCount = externalCount
            }
        });
    }

    [HttpGet("supervisors")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.ExamSupervisor)]
    public async Task<IActionResult> GetForumSupervisors()
    {
        // Filter teachers whose TaskRole contains "التحفيظ" or "منتدى الحفاظ"
        var allTeachers = await _db.Teachers.Where(t => t.IsActive).OrderBy(t => t.FullName).ToListAsync();
        var authorizedSupervisors = allTeachers
            .Where(t => !string.IsNullOrEmpty(t.TaskRole) && 
                       (t.TaskRole.Contains("التحفيظ") || t.TaskRole.Contains("منتدى الحفاظ") || t.TaskRole.Contains("الحفاظ") || t.TaskRole.Contains("مركز البيان")))
            .Select(t => new
            {
                t.Id,
                t.FullName,
                t.TaskRole,
                t.Contact
            })
            .ToList();

        // If no teacher specifically has this role yet, return all active teachers as fallback with indicator
        var result = authorizedSupervisors.Any() 
            ? authorizedSupervisors 
            : allTeachers.Select(t => new { t.Id, t.FullName, t.TaskRole, t.Contact }).ToList();

        return Ok(result);
    }

    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> Create([FromBody] CreateHuffazMemberDto dto)
    {
        string memberType = string.IsNullOrWhiteSpace(dto.MemberType) ? "Student" : dto.MemberType.Trim();
        string fullName = dto.FullName?.Trim() ?? "";
        string? idNumber = dto.IdentityNumber?.Trim();
        string? phone = dto.PhoneNumber?.Trim();

        if (memberType == "Teacher")
        {
            if (!dto.TeacherId.HasValue || dto.TeacherId.Value <= 0)
                return BadRequest(new { error = "يرجى اختيار المعلم من كادر المركز." });

            var teacher = await _db.Teachers.FindAsync(dto.TeacherId.Value);
            if (teacher == null) return NotFound(new { error = "المعلم غير موجود." });

            fullName = teacher.FullName;
            idNumber = string.IsNullOrWhiteSpace(idNumber) ? teacher.IdentityNumber : idNumber;
            phone = string.IsNullOrWhiteSpace(phone) ? teacher.Contact : phone;
        }
        else if (memberType == "Student")
        {
            if (!dto.StudentId.HasValue || dto.StudentId.Value <= 0)
                return BadRequest(new { error = "يرجى اختيار الطالب من طلاب المركز." });

            var student = await _db.Students.FindAsync(dto.StudentId.Value);
            if (student == null) return NotFound(new { error = "الطالب غير موجود." });

            fullName = student.FullName;
            idNumber = string.IsNullOrWhiteSpace(idNumber) ? student.StudentIdentityNumber : idNumber;
            phone = string.IsNullOrWhiteSpace(phone) ? student.StudentMobile : phone;
        }
        else // External
        {
            if (string.IsNullOrWhiteSpace(fullName))
                return BadRequest(new { error = "يرجى إدخال الاسم الرباعي للحافظ الخارجي." });
        }

        int ajzaa = dto.MemorizedAjzaaCount;
        if (ajzaa < 1) ajzaa = 1;
        if (ajzaa > 30) ajzaa = 30;

        bool isKhatim = dto.IsKhatim || ajzaa == 30;

        DateOnly jDate = DateOnly.FromDateTime(DateTime.Today);
        if (!string.IsNullOrWhiteSpace(dto.JoinDate) && DateOnly.TryParse(dto.JoinDate, out var parsedDate))
        {
            jDate = parsedDate;
        }

        var member = new HuffazMember
        {
            MemberType = memberType,
            TeacherId = memberType == "Teacher" ? dto.TeacherId : null,
            StudentId = memberType == "Student" ? dto.StudentId : null,
            FullName = fullName,
            IdentityNumber = idNumber,
            PhoneNumber = phone,
            MemorizedAjzaaCount = ajzaa,
            IsKhatim = isKhatim,
            Riwayah = dto.Riwayah?.Trim(),
            SupervisorTeacherId = dto.SupervisorTeacherId > 0 ? dto.SupervisorTeacherId : null,
            RevisionPlan = dto.RevisionPlan?.Trim(),
            Notes = dto.Notes?.Trim(),
            JoinDate = jDate,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _db.HuffazMembers.Add(member);

        // Auto-provision user account if IdentityNumber is provided and user does not exist yet
        if (!string.IsNullOrWhiteSpace(idNumber))
        {
            var userExists = await _db.Users.AnyAsync(u => u.Username.ToLower() == idNumber.ToLower());
            if (!userExists)
            {
                var newUser = new User
                {
                    Username = idNumber,
                    FullName = fullName,
                    Role = UserRole.Student,
                    StudentId = member.StudentId,
                    TeacherId = member.TeacherId,
                    IsActive = true,
                    PasswordHash = _hasher.HashPassword(idNumber),
                    PlainPassword = idNumber
                };
                _db.Users.Add(newUser);
            }
        }

        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "AddHuffazMember",
            $"إضافة عضو جديد لمنتدى الحفاظ ({member.FullName}) - صفة: {member.MemberType} - حفظ: {member.MemorizedAjzaaCount} جزء");

        return Ok(new { member.Id, Message = $"تمت إضافة الحافظ ({member.FullName}) إلى منتدى الحفاظ بنجاح! 📖" });
    }

    [HttpPut("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> Update(int id, [FromBody] CreateHuffazMemberDto dto)
    {
        var member = await _db.HuffazMembers.FindAsync(id);
        if (member == null) return NotFound(new { error = "عضو المنتدى غير موجود." });

        if (!string.IsNullOrWhiteSpace(dto.FullName)) member.FullName = dto.FullName.Trim();
        if (dto.IdentityNumber != null) member.IdentityNumber = dto.IdentityNumber.Trim();
        if (dto.PhoneNumber != null) member.PhoneNumber = dto.PhoneNumber.Trim();

        if (dto.MemorizedAjzaaCount > 0)
        {
            member.MemorizedAjzaaCount = Math.Clamp(dto.MemorizedAjzaaCount, 1, 30);
            member.IsKhatim = dto.IsKhatim || member.MemorizedAjzaaCount == 30;
        }

        member.Riwayah = dto.Riwayah?.Trim();
        member.SupervisorTeacherId = dto.SupervisorTeacherId > 0 ? dto.SupervisorTeacherId : null;
        member.RevisionPlan = dto.RevisionPlan?.Trim();
        member.Notes = dto.Notes?.Trim();

        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "UpdateHuffazMember",
            $"تعديل بيانات عضو منتدى الحفاظ ID #{id} ({member.FullName})");

        return Ok(new { Message = "تم تحديث بيانات الحافظ بنجاح." });
    }

    [HttpDelete("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> Delete(int id)
    {
        var member = await _db.HuffazMembers.FindAsync(id);
        if (member == null) return NotFound(new { error = "عضو المنتدى غير موجود." });

        _db.HuffazMembers.Remove(member);
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "DeleteHuffazMember",
            $"حذف عضو منتدى الحفاظ ID #{id} ({member.FullName})");

        return Ok(new { Message = "تمت إزالة العضو من منتدى الحفاظ بنجاح." });
    }
}

public record CreateHuffazMemberDto(
    string MemberType,
    int? TeacherId,
    int? StudentId,
    string FullName,
    string? IdentityNumber,
    string? PhoneNumber,
    int MemorizedAjzaaCount,
    bool IsKhatim,
    string? Riwayah,
    int? SupervisorTeacherId,
    string? RevisionPlan,
    string? Notes,
    string? JoinDate
);
