using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class TeacherService
{
    private readonly AppDbContext _db;
    private readonly PasswordHasher _hasher;

    public TeacherService(AppDbContext db, PasswordHasher hasher)
    {
        _db = db;
        _hasher = hasher;
    }

    public async Task<List<TeacherDto>> GetAllAsync(string? search)
    {
        var q = _db.Teachers.AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(t => t.FullName.Contains(search) || (t.IdentityNumber != null && t.IdentityNumber.Contains(search)) || (t.Contact != null && t.Contact.Contains(search)));

        var teachers = await q.ToListAsync();

        var parentCounts = await _db.Students
            .Where(s => !string.IsNullOrEmpty(s.ParentIdentityNumber))
            .GroupBy(s => s.ParentIdentityNumber!.Trim())
            .Select(g => new { Id = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Id, g => g.Count);

        return teachers.Select(t => {
            var count = (!string.IsNullOrEmpty(t.IdentityNumber) && parentCounts.TryGetValue(t.IdentityNumber.Trim(), out var c)) ? c : 0;
            return Map(t, count > 0, count);
        }).ToList();
    }

    public async Task<TeacherDto?> GetByIdAsync(int id)
    {
        var t = await _db.Teachers.FindAsync(id);
        return t is null ? null : Map(t);
    }

    public async Task<(TeacherDto? dto, string? error)> CreateAsync(CreateTeacherDto dto)
    {
        var err = Validate(dto.FullName, dto.Contact, dto.DateOfBirth);
        if (err is not null) return (null, err);

        var idNumber = !string.IsNullOrWhiteSpace(dto.IdentityNumber) ? dto.IdentityNumber.Trim() : null;
        var preferredUsername = !string.IsNullOrWhiteSpace(idNumber)
            ? idNumber
            : (!string.IsNullOrWhiteSpace(dto.Username) ? dto.Username.Trim() : "tch_" + Random.Shared.Next(10000, 99999));

        var password = string.IsNullOrWhiteSpace(dto.Password)
            ? PasswordHasher.GenerateTemporaryPassword()
            : dto.Password.Trim();

        var t = new Teacher
        {
            FullName = dto.FullName.Trim(),
            Address = dto.Address?.Trim() ?? "",
            DateOfBirth = dto.DateOfBirth ?? DateOnly.FromDateTime(DateTime.Today),
            Contact = dto.Contact?.Trim() ?? "",
            RegistrationDate = DateOnly.FromDateTime(DateTime.Today),
            IsActive = true,
            IdentityNumber = idNumber,
            WhatsappNumber = dto.WhatsappNumber?.Trim(),
            SocialStatus = dto.SocialStatus?.Trim(),
            FamilyMembersCount = dto.FamilyMembersCount,
            MosqueName = dto.MosqueName?.Trim(),
            Qualification = dto.Qualification?.Trim(),
            TaskRole = dto.TaskRole?.Trim(),
            WalletNumber = dto.WalletNumber?.Trim(),
            WalletOwner = dto.WalletOwner?.Trim(),
            MemorizedAjzaa = dto.MemorizedAjzaa?.Trim(),
            StudentsCountTarget = dto.StudentsCountTarget?.Trim()
        };
        _db.Teachers.Add(t);
        await _db.SaveChangesAsync();

        // 1. Check if a User already exists for this person (e.g. registered as a Parent earlier via their Identity Number)
        User? user = null;
        if (!string.IsNullOrEmpty(idNumber))
        {
            user = await _db.Users.FirstOrDefaultAsync(u => u.Username == idNumber || (u.TeacherId.HasValue && u.TeacherId == t.Id));
        }
        if (user == null && !string.IsNullOrWhiteSpace(dto.Username))
        {
            user = await _db.Users.FirstOrDefaultAsync(u => u.Username.ToLower() == dto.Username.Trim().ToLower());
        }

        if (user != null)
        {
            user.TeacherId = t.Id;
            user.FullName = t.FullName;
            if (user.Role == UserRole.Parent)
            {
                user.Role = UserRole.Teacher;
            }
            if (!string.IsNullOrEmpty(idNumber))
            {
                user.Username = idNumber;
            }
            user.IsActive = true;
            await _db.SaveChangesAsync();
        }
        else
        {
            var finalUsername = preferredUsername;
            var userExists = await _db.Users.AnyAsync(u => u.Username.ToLower() == finalUsername.ToLower());
            if (userExists) finalUsername = "tch_" + Random.Shared.Next(100000, 999999);

            user = new User
            {
                Username = finalUsername,
                PasswordHash = _hasher.HashPassword(password),
                PlainPassword = string.Empty,
                Role = UserRole.Teacher,
                FullName = t.FullName,
                TeacherId = t.Id,
                IsActive = true
            };
            _db.Users.Add(user);
            await _db.SaveChangesAsync();
        }

        // 2. BI-DIRECTIONAL PARENT-CHILD LINK:
        // If this teacher's National Identity matches any students' ParentIdentityNumber, link them immediately!
        if (!string.IsNullOrEmpty(idNumber) && user != null)
        {
            var matchingStudents = await _db.Students.Where(s => s.ParentIdentityNumber == idNumber).ToListAsync();
            if (matchingStudents.Count > 0)
            {
                user.ParentId = user.Id;
                foreach (var st in matchingStudents)
                {
                    st.ParentId = user.Id;
                }
                await _db.SaveChangesAsync();
            }
        }

        return (Map(t), null);
    }

    public async Task<(bool ok, string? error)> UpdateAsync(int id, UpdateTeacherDto dto)
    {
        var t = await _db.Teachers.FindAsync(id);
        if (t is null) return (false, "المعلّم غير موجود.");

        if (!string.IsNullOrWhiteSpace(dto.FullName))
        {
            var err = Validate(dto.FullName, dto.Contact, t.DateOfBirth);
            if (err is not null) return (false, err);
            t.FullName = dto.FullName.Trim();
        }

        if (dto.Address != null) t.Address = dto.Address.Trim();
        if (dto.Contact != null) t.Contact = dto.Contact.Trim();
        if (dto.DateOfBirth.HasValue) t.DateOfBirth = dto.DateOfBirth.Value;
        if (dto.IsActive.HasValue) t.IsActive = dto.IsActive.Value;

        if (dto.IdentityNumber != null) t.IdentityNumber = dto.IdentityNumber.Trim();
        if (dto.WhatsappNumber != null) t.WhatsappNumber = dto.WhatsappNumber.Trim();
        if (dto.SocialStatus != null) t.SocialStatus = dto.SocialStatus.Trim();
        if (dto.FamilyMembersCount.HasValue) t.FamilyMembersCount = dto.FamilyMembersCount.Value;
        if (dto.MosqueName != null) t.MosqueName = dto.MosqueName.Trim();
        if (dto.Qualification != null) t.Qualification = dto.Qualification.Trim();
        if (dto.TaskRole != null) t.TaskRole = dto.TaskRole.Trim();
        if (dto.WalletNumber != null) t.WalletNumber = dto.WalletNumber.Trim();
        if (dto.WalletOwner != null) t.WalletOwner = dto.WalletOwner.Trim();
        if (dto.MemorizedAjzaa != null) t.MemorizedAjzaa = dto.MemorizedAjzaa.Trim();
        if (dto.StudentsCountTarget != null) t.StudentsCountTarget = dto.StudentsCountTarget.Trim();

        var u = await _db.Users.FirstOrDefaultAsync(x => x.TeacherId == id);
        if (u != null)
        {
            u.FullName = t.FullName;
            if (!string.IsNullOrWhiteSpace(t.IdentityNumber))
            {
                u.Username = t.IdentityNumber;
            }
            if (dto.IsActive.HasValue)
            {
                u.IsActive = t.IsActive;
            }

            // Account roles are changed explicitly in system account management.
            // Editing the teacher's job description must never elevate privileges.
        }

        // If teacher is stripped of circle roles (e.g. empty or without حلقة / مساعد), unassign from circles
        if (t.TaskRole == null || (!t.TaskRole.Contains("حلقة") && !t.TaskRole.Contains("مساعد")))
        {
            var circlesToUnlink = await _db.Circles.Where(c => c.TeacherId == id || c.AssistantTeacherId == id).ToListAsync();
            foreach (var c in circlesToUnlink)
            {
                if (c.TeacherId == id) c.TeacherId = null;
                if (c.AssistantTeacherId == id) c.AssistantTeacherId = null;
            }
        }

        // RE-LINK STUDENTS to Teacher if IdentityNumber exists
        if (!string.IsNullOrWhiteSpace(t.IdentityNumber))
        {
            var userRecord = u ?? await _db.Users.FirstOrDefaultAsync(x => x.TeacherId == t.Id || x.Username == t.IdentityNumber);
            if (userRecord != null)
            {
                var matchingChildren = await _db.Students.Where(s => s.ParentIdentityNumber == t.IdentityNumber).ToListAsync();
                if (matchingChildren.Count > 0)
                {
                    userRecord.ParentId = userRecord.Id;
                    foreach (var mc in matchingChildren)
                    {
                        mc.ParentId = userRecord.Id;
                    }
                }
            }
        }

        await _db.SaveChangesAsync();
        return (true, null);
    }

    public async Task<bool> DeactivateAsync(int id)
    {
        var t = await _db.Teachers.FindAsync(id);
        if (t is null) return false;
        t.IsActive = false;

        var u = await _db.Users.FirstOrDefaultAsync(x => x.TeacherId == id);
        if (u is not null) u.IsActive = false;

        await _db.SaveChangesAsync();
        return true;
    }

    public async Task<(bool ok, string teacherName, string? error)> HardDeleteAsync(int id)
    {
        var t = await _db.Teachers.FindAsync(id);
        if (t is null) return (false, "", "المعلم غير موجود.");

        var teacherName = t.FullName;

        try
        {
            // 1. فك ارتباط الحلقات التعليمية (كمعلم أساسي أو مساعد)
            var circles = await _db.Circles.Where(c => c.TeacherId == id || c.AssistantTeacherId == id).ToListAsync();
            foreach (var c in circles)
            {
                if (c.TeacherId == id) c.TeacherId = null;
                if (c.AssistantTeacherId == id) c.AssistantTeacherId = null;
            }

            // 2. فك ارتباط الدورات والمساقات (كمدرس أو كمشرف اختبار)
            var courses = await _db.Courses.Where(c => c.TeacherId == id || c.ExamSupervisorId == id).ToListAsync();
            foreach (var co in courses)
            {
                if (co.TeacherId == id) co.TeacherId = null;
                if (co.ExamSupervisorId == id) co.ExamSupervisorId = null;
            }

            // 3. فك ارتباط ترشيحات الاختبارات
            var examNoms = await _db.ExamNominations.Where(en => en.TeacherId == id).ToListAsync();
            foreach (var en in examNoms)
            {
                en.TeacherId = null;
            }

            // 4. فك ارتباط سجلات المواهب والأنشطة
            var talents = await _db.TalentRecords.Where(tr => tr.SupervisorTeacherId == id).ToListAsync();
            foreach (var tr in talents)
            {
                tr.SupervisorTeacherId = null;
            }

            // 5. فك ارتباط كادر الحفاظ (كمعلم أو كمشرف)
            var huffaz = await _db.HuffazMembers.Where(h => h.TeacherId == id || h.SupervisorTeacherId == id).ToListAsync();
            foreach (var h in huffaz)
            {
                if (h.TeacherId == id) h.TeacherId = null;
                if (h.SupervisorTeacherId == id) h.SupervisorTeacherId = null;
            }

            // 6. حذف أو تنظيف حسابات المستخدمين المرتبطة بالمعلم
            var users = await _db.Users.Where(u => u.TeacherId == id || (!string.IsNullOrWhiteSpace(t.IdentityNumber) && u.Username == t.IdentityNumber)).ToListAsync();
            foreach (var user in users)
            {
                user.Teacher = t;
                var children = (await _db.Students.ToListAsync()).Where(st => ParentLinks.IsChild(user, st)).ToList();
                foreach (var child in children) child.ParentId = user.Id;
                user.TeacherId = null;
                user.Teacher = null;
                user.TokenVersion++;
                if (children.Count > 0)
                {
                    user.ParentId = user.Id;
                    if (user.Role == UserRole.Teacher) user.Role = UserRole.Parent;
                    user.IsActive = true;
                }
                else if (user.Role == UserRole.Teacher) user.IsActive = false;

            }

            // حفظ فك الارتباط أولاً لتفريغ قيود المفاتيح الأجنبية في قاعدة البيانات
            await _db.SaveChangesAsync();

            // 7. حذف المعلم نهائياً وحفظ التغييرات
            _db.Teachers.Remove(t);
            await _db.SaveChangesAsync();

            return (true, teacherName, null);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[HardDeleteTeacher Error] Failed deleting teacher #{id} ({teacherName}): {ex.Message} -> {ex.InnerException?.Message}");
            return (false, teacherName, $"تعذر حذف المعلم لوجود ارتباطات في قاعدة البيانات: {ex.InnerException?.Message ?? ex.Message}");
        }
    }

    public async Task<(bool ok, bool newStatus, string? error)> ToggleActiveAsync(int id)
    {
        var t = await _db.Teachers.FindAsync(id);
        if (t is null) return (false, false, "المعلم غير موجود.");
        t.IsActive = !t.IsActive;

        var u = await _db.Users.FirstOrDefaultAsync(x => x.TeacherId == id);
        if (u is not null) u.IsActive = t.IsActive;

        await _db.SaveChangesAsync();
        return (true, t.IsActive, null);
    }

    private static string? Validate(string fullName, string? contact, DateOnly? dob)
    {
        if (string.IsNullOrWhiteSpace(fullName)) return "اسم المعلم مطلوب.";
        return null;
    }

    private static TeacherDto Map(Teacher t, bool hasChildren = false, int childrenCount = 0) => new(
        t.Id,
        t.FullName,
        t.Address,
        t.DateOfBirth,
        t.Contact,
        t.RegistrationDate,
        t.IsActive,
        t.IdentityNumber,
        t.WhatsappNumber,
        t.SocialStatus,
        t.FamilyMembersCount,
        t.MosqueName,
        t.Qualification,
        t.TaskRole,
        t.WalletNumber,
        t.WalletOwner,
        t.MemorizedAjzaa,
        t.StudentsCountTarget,
        hasChildren,
        childrenCount
    );

}
