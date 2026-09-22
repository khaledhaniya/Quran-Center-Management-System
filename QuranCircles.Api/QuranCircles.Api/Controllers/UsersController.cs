using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/users")]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly PasswordHasher _hasher;

    public UsersController(AppDbContext db, PasswordHasher hasher)
    {
        _db = db;
        _hasher = hasher;
    }

    [HttpGet]
    [RequireRole(UserRole.Developer, UserRole.Admin)]
    public async Task<IActionResult> GetAll()
    {
        var users = await _db.Users
            .Include(u => u.Teacher)
            .Include(u => u.Student)
            .ToListAsync();

        var allStudents = await _db.Students
            .Select(s => new { s.Id, s.FullName, s.ParentId, s.ParentIdentityNumber, s.FamilyContact })
            .ToListAsync();

        var allTeachers = await _db.Teachers
            .Select(t => new { t.Id, t.FullName, t.IdentityNumber, t.TaskRole })
            .ToListAsync();

        var result = users.Select(u => {
            string? idNum = null;
            string? taskRole = null;

            if (u.Role == UserRole.Teacher)
            {
                if (u.Teacher != null)
                {
                    idNum = u.Teacher.IdentityNumber;
                    taskRole = u.Teacher.TaskRole;
                }
                else if (u.TeacherId.HasValue)
                {
                    var matchedT = allTeachers.FirstOrDefault(t => t.Id == u.TeacherId.Value);
                    if (matchedT != null)
                    {
                        idNum = matchedT.IdentityNumber;
                        taskRole = matchedT.TaskRole;
                    }
                }

                if (string.IsNullOrWhiteSpace(taskRole))
                {
                    var matchedT = allTeachers.FirstOrDefault(t => 
                        (!string.IsNullOrWhiteSpace(t.IdentityNumber) && t.IdentityNumber.Trim() == u.Username.Trim()) ||
                        (!string.IsNullOrWhiteSpace(t.FullName) && t.FullName.Trim().Equals(u.FullName.Trim(), StringComparison.OrdinalIgnoreCase))
                    );
                    if (matchedT != null)
                    {
                        if (string.IsNullOrWhiteSpace(idNum)) idNum = matchedT.IdentityNumber;
                        taskRole = matchedT.TaskRole;
                    }
                }
            }
            else if (u.Role == UserRole.Student && u.Student != null)
            {
                idNum = u.Student.StudentIdentityNumber;
            }
            else if (u.Role == UserRole.Parent)
            {
                int pId = u.ParentId ?? u.Id;
                // 1. Try matching student by ParentId
                var matchedStudent = allStudents.FirstOrDefault(s => (s.ParentId.HasValue && (s.ParentId == pId || s.ParentId == u.Id)) && !string.IsNullOrWhiteSpace(s.ParentIdentityNumber));
                
                // 2. If not found, try matching by Username matching student's ParentIdentityNumber or FamilyContact
                if (matchedStudent == null && !string.IsNullOrWhiteSpace(u.Username))
                {
                    var uName = u.Username.Trim();
                    matchedStudent = allStudents.FirstOrDefault(s => 
                        (!string.IsNullOrWhiteSpace(s.ParentIdentityNumber) && s.ParentIdentityNumber.Trim() == uName) ||
                        (!string.IsNullOrWhiteSpace(s.FamilyContact) && s.FamilyContact.Trim() == uName)
                    );
                }

                if (matchedStudent != null && !string.IsNullOrWhiteSpace(matchedStudent.ParentIdentityNumber))
                {
                    idNum = matchedStudent.ParentIdentityNumber.Trim();
                }
                else if (!string.IsNullOrWhiteSpace(u.Username) && u.Username.Trim().All(char.IsDigit))
                {
                    idNum = u.Username.Trim();
                }
            }

            return new {
                u.Id,
                u.Username,
                u.FullName,
                Role = u.Role.ToString(),
                TaskRole = taskRole,
                u.IsActive,
                u.TeacherId,
                u.StudentId,
                u.ParentId,
                IdentityNumber = !string.IsNullOrWhiteSpace(idNum) ? idNum : "-",
                PlainPassword = !string.IsNullOrEmpty(u.PlainPassword) 
                    ? u.PlainPassword 
                    : (u.Username == "dev" ? "dev123" : (u.Username == "admin" ? "admin123" : (u.Username == "wael" ? "wael123" : "123456")))
            };
        }).ToList();

        return Ok(result);
    }

    [HttpPost]
    [RequireRole(UserRole.Developer, UserRole.Admin)]
    public async Task<IActionResult> Create([FromBody] CreateUserDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
            return BadRequest(new { error = "اسم المستخدم وكلمة المرور مطلوبان." });

        var taken = await _db.Users.AnyAsync(u => u.Username.ToLower() == dto.Username.ToLower().Trim());
        if (taken) return BadRequest(new { error = "اسم المستخدم محجوز بالفعل." });

        if (!Enum.TryParse<UserRole>(dto.Role, out var roleVal))
            return BadRequest(new { error = "نوع الحساب غير صالح." });

        int? teacherId = dto.TeacherId;
        int? studentId = dto.StudentId;
        int? parentId = dto.ParentId;

        // Auto-heal Student linking if creating a Student user
        if (roleVal == UserRole.Student && !studentId.HasValue)
        {
            var matchedS = await _db.Students.FirstOrDefaultAsync(s =>
                (!string.IsNullOrWhiteSpace(s.StudentIdentityNumber) && s.StudentIdentityNumber.Trim() == dto.Username.Trim()) ||
                s.FullName.Trim().ToLower() == dto.FullName.Trim().ToLower());
            if (matchedS != null)
            {
                studentId = matchedS.Id;
                matchedS.FullName = dto.FullName.Trim();
                if (string.IsNullOrWhiteSpace(matchedS.StudentIdentityNumber))
                    matchedS.StudentIdentityNumber = dto.Username.Trim();
            }
        }
        else if (roleVal == UserRole.Teacher && !teacherId.HasValue)
        {
            var matchedT = await _db.Teachers.FirstOrDefaultAsync(t =>
                (!string.IsNullOrWhiteSpace(t.IdentityNumber) && t.IdentityNumber.Trim() == dto.Username.Trim()) ||
                t.FullName.Trim().ToLower() == dto.FullName.Trim().ToLower());
            if (matchedT != null)
            {
                teacherId = matchedT.Id;
                matchedT.FullName = dto.FullName.Trim();
                if (string.IsNullOrWhiteSpace(matchedT.IdentityNumber))
                    matchedT.IdentityNumber = dto.Username.Trim();
            }
        }

        var user = new User
        {
            Username = dto.Username.Trim(),
            FullName = dto.FullName.Trim(),
            Role = roleVal,
            TeacherId = teacherId,
            StudentId = studentId,
            ParentId = parentId,
            IsActive = true,
            PasswordHash = _hasher.HashPassword(dto.Password.Trim()),
            PlainPassword = dto.Password.Trim()
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "CreateUser", $"إنشاء حساب جديد للمستخدم: {user.Username} ({user.FullName}) - الصفة: {user.Role}");

        return CreatedAtAction(nameof(GetAll), new { id = user.Id }, new {
            user.Id,
            user.Username,
            user.FullName,
            Role = user.Role.ToString(),
            user.TeacherId,
            user.StudentId,
            user.ParentId,
            user.IsActive,
            user.PlainPassword
        });
    }

    [HttpPut("{id:int}")]
    [RequireRole(UserRole.Developer, UserRole.Admin)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateUserDto dto)
    {
        var user = await _db.Users.FindAsync(id);
        if (user == null) return NotFound(new { error = "المستخدم غير موجود." });

        if (string.IsNullOrWhiteSpace(dto.Username)) 
            return BadRequest(new { error = "اسم المستخدم مطلوب." });

        var taken = await _db.Users.AnyAsync(u => u.Id != id && u.Username.ToLower() == dto.Username.ToLower().Trim());
        if (taken) return BadRequest(new { error = "اسم المستخدم محجوز بالفعل." });

        string oldUsername = user.Username;
        string oldFullName = user.FullName;

        user.Username = dto.Username.Trim();
        user.FullName = dto.FullName.Trim();
        if (dto.TeacherId.HasValue) user.TeacherId = dto.TeacherId.Value > 0 ? dto.TeacherId.Value : null;
        if (dto.StudentId.HasValue) user.StudentId = dto.StudentId.Value > 0 ? dto.StudentId.Value : null;
        if (dto.ParentId.HasValue) user.ParentId = dto.ParentId.Value > 0 ? dto.ParentId.Value : null;
        
        if (Enum.TryParse<UserRole>(dto.Role, out var roleVal))
        {
            user.Role = roleVal;
        }

        if (dto.IsActive.HasValue)
        {
            user.IsActive = dto.IsActive.Value;
        }

        if (!string.IsNullOrWhiteSpace(dto.Password))
        {
            user.PasswordHash = _hasher.HashPassword(dto.Password.Trim());
            user.PlainPassword = dto.Password.Trim();
        }

        // --- Synchronize with Student Record ---
        Student? student = null;
        if (user.StudentId.HasValue)
        {
            student = await _db.Students.FindAsync(user.StudentId.Value);
        }
        if (student == null && (user.Role == UserRole.Student || roleVal == UserRole.Student))
        {
            student = await _db.Students.FirstOrDefaultAsync(s =>
                (!string.IsNullOrWhiteSpace(s.StudentIdentityNumber) && (s.StudentIdentityNumber.Trim() == oldUsername || s.StudentIdentityNumber.Trim() == user.Username)) ||
                s.FullName.Trim().ToLower() == oldFullName.ToLower() ||
                s.FullName.Trim().ToLower() == user.FullName.ToLower());
            if (student != null)
            {
                user.StudentId = student.Id;
            }
        }
        if (student != null)
        {
            student.FullName = user.FullName;
            if (dto.IsActive.HasValue) student.IsActive = dto.IsActive.Value;
            // Only set StudentIdentityNumber if completely empty
            if (string.IsNullOrWhiteSpace(student.StudentIdentityNumber))
            {
                student.StudentIdentityNumber = user.Username;
            }
        }

        // --- Synchronize with Teacher Record ---
        Teacher? teacher = null;
        if (user.TeacherId.HasValue)
        {
            teacher = await _db.Teachers.FindAsync(user.TeacherId.Value);
        }
        if (teacher == null && (user.Role == UserRole.Teacher || roleVal == UserRole.Teacher))
        {
            teacher = await _db.Teachers.FirstOrDefaultAsync(t =>
                (!string.IsNullOrWhiteSpace(t.IdentityNumber) && (t.IdentityNumber.Trim() == oldUsername || t.IdentityNumber.Trim() == user.Username)) ||
                t.FullName.Trim().ToLower() == oldFullName.ToLower() ||
                t.FullName.Trim().ToLower() == user.FullName.ToLower());
            if (teacher != null)
            {
                user.TeacherId = teacher.Id;
            }
        }
        if (teacher != null)
        {
            teacher.FullName = user.FullName;
            if (dto.IsActive.HasValue) teacher.IsActive = dto.IsActive.Value;
            if (string.IsNullOrWhiteSpace(teacher.IdentityNumber) || teacher.IdentityNumber.Trim() == oldUsername)
            {
                teacher.IdentityNumber = user.Username;
            }
        }

        // --- Synchronize with Parent Record ---
        if (user.Role == UserRole.Parent || user.ParentId.HasValue)
        {
            var pId = user.ParentId ?? user.Id;
            var linkedChildren = await _db.Students.Where(s => s.ParentId == pId).ToListAsync();
            foreach (var ch in linkedChildren)
            {
                if (string.IsNullOrWhiteSpace(ch.ParentIdentityNumber) || ch.ParentIdentityNumber.Trim() == oldUsername)
                {
                    ch.ParentIdentityNumber = user.Username;
                }
            }
        }

        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "UpdateUser", $"تعديل حساب المستخدم: {user.Username} ({user.FullName}) - الصفة: {user.Role} - الحالة: {(user.IsActive ? "نشط" : "معطل")}");

        return Ok(new { 
            message = "تم تحديث الحساب وكلمة المرور ومزامنة البيانات بنجاح.",
            user.Id,
            user.Username,
            user.FullName,
            user.Role,
            user.TeacherId,
            user.StudentId,
            user.ParentId,
            user.IsActive,
            user.PlainPassword
        });
    }

    [HttpPatch("{id:int}/toggle-status")]
    [RequireRole(UserRole.Developer, UserRole.Admin)]
    public async Task<IActionResult> ToggleStatus(int id)
    {
        var user = await _db.Users.FindAsync(id);
        if (user == null) return NotFound(new { error = "المستخدم غير موجود." });

        user.IsActive = !user.IsActive;
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "ToggleUserStatus", $"تغيير حالة الحساب للمستخدم: {user.Username} إلى {(user.IsActive ? "نشط" : "معطل")}");

        return Ok(new { 
            id = user.Id, 
            isActive = user.IsActive, 
            message = user.IsActive ? "تم تفعيل وتنشيط الحساب بنجاح." : "تم تعطيل الحساب بنجاح." 
        });
    }

    [HttpDelete("{id:int}")]
    [RequireRole(UserRole.Developer, UserRole.Admin)]
    public async Task<IActionResult> Delete(int id)
    {
        var user = await _db.Users.FindAsync(id);
        if (user == null) return NotFound(new { error = "المستخدم غير موجود." });

        var uName = user.Username;
        var fName = user.FullName;
        var uRole = user.Role;

        _db.Users.Remove(user);
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "DeleteUser", $"حذف الحساب نهائياً للمستخدم: {uName} ({fName}) - الصفة: {uRole}");

        return NoContent();
    }

    [HttpGet("supervisors")]
    [RequireRole(UserRole.Developer, UserRole.Admin, UserRole.Teacher, UserRole.ExamSupervisor)]
    public async Task<IActionResult> GetSupervisors()
    {
        var result = new List<object>();

        // 1. Direct ExamSupervisor users
        var userSupervisors = await _db.Users
            .Where(u => u.Role == UserRole.ExamSupervisor && u.IsActive)
            .Select(u => new
            {
                u.Id,
                u.TeacherId,
                u.FullName,
                u.Username,
                IsSpecialist = true
            })
            .ToListAsync();

        result.AddRange(userSupervisors);

        // 2. Teachers whose TaskRole in Teachers Management specifies exam supervision
        var examTeachers = await _db.Teachers
            .Where(t => t.IsActive && t.TaskRole != null &&
                       (t.TaskRole.Contains("مشرف اختبارات") || t.TaskRole.Contains("اختبار") || t.TaskRole.Contains("امتحان")))
            .ToListAsync();

        foreach (var t in examTeachers)
        {
            var u = await _db.Users.FirstOrDefaultAsync(x => x.TeacherId == t.Id);
            if (!userSupervisors.Any(us => us.TeacherId == t.Id || us.FullName == t.FullName))
            {
                result.Add(new
                {
                    Id = u?.Id ?? t.Id,
                    TeacherId = (int?)t.Id,
                    FullName = t.FullName,
                    Username = u?.Username ?? t.IdentityNumber ?? "",
                    IsSpecialist = true
                });
            }
        }

        return Ok(result);
    }
}

public record CreateUserDto(
    string Username,
    string FullName,
    string Role,
    string Password,
    int? TeacherId = null,
    int? StudentId = null,
    int? ParentId = null
);

public record UpdateUserDto(
    string Username,
    string FullName,
    string Role,
    string? Password = null,
    int? TeacherId = null,
    int? StudentId = null,
    int? ParentId = null,
    bool? IsActive = null
);
