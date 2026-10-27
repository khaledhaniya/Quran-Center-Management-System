using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly PasswordHasher _hasher;
    private readonly TokenService _tokenSvc;
    private readonly ReportService _reportSvc;
    private readonly PasswordVault? _vault;

    public AuthController(AppDbContext db, PasswordHasher hasher, TokenService tokenSvc, ReportService reportSvc, PasswordVault? vault = null)
    {
        _db = db;
        _hasher = hasher;
        _tokenSvc = tokenSvc;
        _reportSvc = reportSvc;
        _vault = vault;
    }

    [HttpPost("login")]
    [Microsoft.AspNetCore.RateLimiting.EnableRateLimiting("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        if (dto == null || string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
            return BadRequest(new { error = "الرجاء إدخال اسم المستخدم وكلمة المرور." });

        var uLower = (dto.Username ?? "").Trim().ToLower();
        var user = await _db.Users
            .Include(u => u.Teacher)
            .Include(u => u.Student)
            .FirstOrDefaultAsync(u => u.Username.ToLower() == uLower);

        // Fallback: If not found by Username, try finding by Teacher IdentityNumber or Contact or FullName
        if (user == null)
        {
            var matchedTeacher = await _db.Teachers.FirstOrDefaultAsync(t =>
                (!string.IsNullOrEmpty(t.IdentityNumber) && t.IdentityNumber.Trim().ToLower() == uLower) ||
                (!string.IsNullOrEmpty(t.Contact) && t.Contact.Trim().ToLower() == uLower) ||
                (!string.IsNullOrEmpty(t.FullName) && t.FullName.Trim().ToLower() == uLower));

            if (matchedTeacher != null)
            {
                user = await _db.Users
                    .Include(u => u.Teacher)
                    .Include(u => u.Student)
                    .FirstOrDefaultAsync(u => u.TeacherId == matchedTeacher.Id || (u.Username != null && u.Username.Trim() == matchedTeacher.IdentityNumber));


            }
        }

        // Fallback: If not found by Username, try finding by Student IdentityNumber or FullName
        if (user == null)
        {
            try
            {
                var matchedStudent = await _db.Students.FirstOrDefaultAsync(s =>
                    (!string.IsNullOrEmpty(s.StudentIdentityNumber) && s.StudentIdentityNumber.Trim().ToLower() == uLower) ||
                    (!string.IsNullOrEmpty(s.FullName) && s.FullName.Trim().ToLower() == uLower));

                if (matchedStudent != null)
                {
                    user = await _db.Users
                        .Include(u => u.Teacher)
                        .Include(u => u.Student)
                        .FirstOrDefaultAsync(u => u.StudentId == matchedStudent.Id || (u.Username != null && u.Username.Trim().ToLower() == uLower));
                }
            }
            catch { }
        }

        // Fallback: If not found by Username, try finding by Parent IdentityNumber or Contact
        if (user == null)
        {
            try
            {
                var matchedChild = await _db.Students.FirstOrDefaultAsync(s =>
                    (!string.IsNullOrEmpty(s.ParentIdentityNumber) && s.ParentIdentityNumber.Trim().ToLower() == uLower) ||
                    (!string.IsNullOrEmpty(s.FamilyContact) && s.FamilyContact.Trim().ToLower() == uLower));

                if (matchedChild != null)
                {
                    var pId = matchedChild.ParentId;
                    var pIdNum = matchedChild.ParentIdentityNumber?.Trim().ToLower();
                    user = await _db.Users
                        .Include(u => u.Teacher)
                        .Include(u => u.Student)
                        .FirstOrDefaultAsync(u => (pId.HasValue && (u.Id == pId.Value || u.ParentId == pId.Value)) ||
                                                  (!string.IsNullOrEmpty(pIdNum) && u.Username.ToLower() == pIdNum));
                }
            }
            catch { }
        }

        if (user == null)
            return BadRequest(new { error = "اسم المستخدم غير موجود." });

        if (!user.IsActive)
            return BadRequest(new { error = "اسم المستخدم غير موجود أو الحساب معطل من قبل الإدارة." });

        bool isPasswordValid = false;
        if (!string.IsNullOrEmpty(user.PasswordHash))
        {
            try
            {
                isPasswordValid = _hasher.VerifyPassword(user.PasswordHash, dto.Password);
            }
            catch
            {
                isPasswordValid = false;
            }
        }

        if (!isPasswordValid)
            return BadRequest(new { error = "كلمة المرور غير صحيحة." });

        if (await _db.SystemSettings.AsNoTracking().AnyAsync(x => x.MaintenanceMode)
            && user.Role != UserRole.Developer)
            return StatusCode(503, new { error = "النظام في وضع الصيانة والتحديث حالياً، ومتاح للمطور فقط.", maintenance = true });

        // Capture the current password after a successful login for pre-existing accounts.
        if (_vault != null && _vault.Unprotect(user.PasswordCiphertext) != dto.Password)
        {
            user.PasswordCiphertext = _vault.Protect(dto.Password);
            await _db.SaveChangesAsync();
        }

        await TeacherPermissions.ResolveLinkAsync(_db,user);
        var effectivePermissions = await TeacherPermissions.EffectiveForAsync(_db,user);
        var token = _tokenSvc.GenerateToken(user);

        // Find reference ID based on role
        int? teacherId = user.TeacherId;
        int? studentId = user.StudentId;
        int? parentId = user.ParentId;

        string? taskRole = null;
        string? mosqueName = null;
        string? qualification = null;
        if (teacherId.HasValue && teacherId.Value > 0)
        {
            try
            {
                var t = user.Teacher ?? await _db.Teachers.FindAsync(teacherId.Value);
                if (t != null)
                {
                    taskRole = t.TaskRole;
                    mosqueName = t.MosqueName;
                    qualification = t.Qualification;
                }
            }
            catch { }
        }

        // Detect dual role: Teacher or User who also has children in the center
        bool hasChildren = false;
        int childrenCount = 0;
        int? resolvedParentId = null;

        if (user.Role != UserRole.Student)
        {
            try
            {
                var children = await _reportSvc.GetSmartChildrenForParentAsync(user);
                if (children != null && children.Count > 0)
                {
                    hasChildren = true;
                    childrenCount = children.Count;
                    resolvedParentId = user.ParentId ?? user.Id;
                }
                else if (user.Role == UserRole.Parent)
                {
                    resolvedParentId = user.ParentId ?? user.Id;
                }
            }
            catch { }
        }

        bool isTeacher = user.Teacher?.IsActive == true && user.TeacherId.HasValue;
        bool isParent = user.Role == UserRole.Parent || hasChildren || (user.ParentId.HasValue && user.ParentId.Value > 0);
        bool isDualRole = isTeacher && isParent;

        var availableRoles = new List<string>();
        if (user.Role == UserRole.Admin || user.Role == UserRole.Developer)
        {
            availableRoles.Add(user.Role.ToString());
            if (isTeacher) availableRoles.Add("Teacher");
            if (isParent) availableRoles.Add("Parent");
        }
        else
        {
            availableRoles.Add(user.Role.ToString());
            if (isTeacher && user.Role != UserRole.Teacher) availableRoles.Add("Teacher");
            if (isParent && user.Role != UserRole.Parent) availableRoles.Add("Parent");
        }
        if (availableRoles.Count == 0) availableRoles.Add(user.Role.ToString());

        return Ok(new
        {
            token,
            role = user.Role.ToString(),
            isTeacher,
            isParent,
            isDualRole,
            availableRoles = availableRoles.Distinct().ToList(),
            userId = user.Id,
            teacherId,
            studentId,
            parentId = resolvedParentId,
            username = user.Username,
            fullName = user.FullName,
            taskRole,
            permissions = effectivePermissions,
            mosqueName,
            qualification,
            hasChildren,
            childrenCount
        });
    }

    [HttpGet("me")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.Student, UserRole.Parent, UserRole.ExamSupervisor)]
    public async Task<IActionResult> Me()
    {
        var user = await _db.Users.Include(u => u.Teacher).SingleAsync(u => u.Id == FakeAuth.GetUserId(HttpContext));
        await TeacherPermissions.ResolveLinkAsync(_db,user);
        var effectivePermissions = await TeacherPermissions.EffectiveForAsync(_db,user);
        var children = user.Role == UserRole.Student ? new List<Student>() : await _reportSvc.GetSmartChildrenForParentAsync(user);
        return Ok(new { userId = user.Id, user.Username, user.FullName, role = user.Role.ToString(), user.TeacherId, user.StudentId, user.ParentId,
            taskRole = user.Teacher?.IsActive == true ? user.Teacher.TaskRole : "", permissions = effectivePermissions,
            hasChildren = children.Count > 0, childrenCount = children.Count });
    }

    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDto dto)
    {
        if (dto == null || string.IsNullOrWhiteSpace(dto.NewPassword))
            return BadRequest(new { error = "يرجى إدخال كلمة المرور الجديدة." });

        var userId = FakeAuth.GetUserId(HttpContext);
        if (!userId.HasValue)
            return Unauthorized(new { error = "جلسة الدخول غير صالحة أو منتهية. يرجى تسجيل الدخول مجدداً." });

        var user = await _db.Users.FindAsync(userId.Value);
        if (user == null || !user.IsActive)
            return NotFound(new { error = "المستخدم غير موجود أو حسابه معطل." });

        var currentRole = FakeAuth.GetRole(HttpContext);
        bool isPrivileged = false; // Changing one's own password always requires the current password.

        if (!isPrivileged || !string.IsNullOrWhiteSpace(dto.CurrentPassword))
        {
            bool currentValid = false;
            if (!string.IsNullOrEmpty(user.PasswordHash))
            {
                try { currentValid = _hasher.VerifyPassword(user.PasswordHash, dto.CurrentPassword ?? ""); }
                catch { currentValid = false; }
            }
            if (!currentValid)
                return BadRequest(new { error = "كلمة المرور الحالية غير صحيحة." });
        }

        var newPw = dto.NewPassword.Trim();
        if (newPw.Length < 8)
            return BadRequest(new { error = "يجب أن لا تقل كلمة المرور الجديدة عن 8 خانات." });

        user.PasswordHash = _hasher.HashPassword(newPw);
        user.PlainPassword = string.Empty;
        user.PasswordCiphertext = _vault?.Protect(newPw) ?? string.Empty;
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "ChangePassword", $"تغيير كلمة المرور للمستخدم: {user.Username} ({user.FullName})");

        return Ok(new {
            message = "تم تغيير كلمة المرور. يرجى تسجيل الدخول مجدداً.",
            requiresLogin = true
        });
    }
}

public record LoginDto(string Username, string Password);
public record ChangePasswordDto(string? CurrentPassword, string NewPassword);
