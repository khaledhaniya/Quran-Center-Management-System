using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class StudentService
{
    private readonly AppDbContext _db;
    private readonly PasswordHasher _hasher;

    public StudentService(AppDbContext db, PasswordHasher hasher)
    {
        _db = db;
        _hasher = hasher;
    }

    public async Task<List<object>> GetAllAsync(string? search)
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

        var students = await query.OrderBy(s => s.FullName).ToListAsync();
        var studentIds = students.Select(s => s.Id).ToList();
        var studentIdentities = students.Where(s => !string.IsNullOrWhiteSpace(s.StudentIdentityNumber)).Select(s => s.StudentIdentityNumber!.Trim().ToLower()).ToList();

        var studentUsers = await _db.Users
            .Where(u => (u.StudentId.HasValue && studentIds.Contains(u.StudentId.Value)) || (u.Role == UserRole.Student && studentIdentities.Contains(u.Username.ToLower())))
            .ToListAsync();

        var studentUserMap = new Dictionary<int, string>();
        bool needsSave = false;
        foreach (var s in students)
        {
            var matchedUser = studentUsers.FirstOrDefault(u => u.StudentId == s.Id)
                           ?? (!string.IsNullOrWhiteSpace(s.StudentIdentityNumber) ? studentUsers.FirstOrDefault(u => u.Username.Trim().ToLower() == s.StudentIdentityNumber.Trim().ToLower()) : null)
                           ?? studentUsers.FirstOrDefault(u => u.FullName.Trim().ToLower() == s.FullName.Trim().ToLower());
            if (matchedUser != null)
            {
                studentUserMap[s.Id] = matchedUser.Username;
                if (!matchedUser.StudentId.HasValue)
                {
                    matchedUser.StudentId = s.Id;
                    needsSave = true;
                }
            }
        }
        if (needsSave)
        {
            try { await _db.SaveChangesAsync(); } catch { }
        }

        var parentIds = students.Where(s => s.ParentId.HasValue).Select(s => s.ParentId!.Value).Distinct().ToList();
        var parentUsers = await _db.Users.Where(u => u.Role == UserRole.Parent && (parentIds.Contains(u.Id) || (u.ParentId.HasValue && parentIds.Contains(u.ParentId.Value)))).ToListAsync();
        var parentMap = parentUsers.ToDictionary(u => u.ParentId ?? u.Id, u => u.FullName);

        return students.Select(s => MapStudentToFullObject(
            s, 
            s.ParentId.HasValue && parentMap.TryGetValue(s.ParentId.Value, out var pName) ? pName : null,
            studentUserMap.TryGetValue(s.Id, out var uName) ? uName : s.StudentIdentityNumber
        )).ToList();
    }

    public async Task<List<object>> GetStudentsForTeacherAsync(int teacherId, string? search, bool onlyCircle = false)
    {
        var query = _db.Students.Include(s => s.Circle).ThenInclude(c => c!.Teacher).AsQueryable();

        if (onlyCircle)
        {
            query = query.Where(s => s.Circle != null && s.Circle.TeacherId == teacherId);
        }
        else
        {
            query = query.Where(s => (s.Circle != null && s.Circle.TeacherId == teacherId)
                || _db.CourseEnrollments.Any(ce => ce.StudentId == s.Id && ce.Course != null && ce.Course.TeacherId == teacherId));
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim().ToLower();
            query = query.Where(s => s.FullName.ToLower().Contains(q)
                || (s.StudentIdentityNumber != null && s.StudentIdentityNumber.Contains(q))
                || (s.FamilyContact != null && s.FamilyContact.Contains(q))
                || (s.StudentMobile != null && s.StudentMobile.Contains(q))
                || (s.Circle != null && s.Circle.Name.ToLower().Contains(q)));
        }

        var students = await query.OrderBy(s => s.Id).ToListAsync();
        var studentIds = students.Select(s => s.Id).ToList();
        var studentIdentities = students.Where(s => !string.IsNullOrWhiteSpace(s.StudentIdentityNumber)).Select(s => s.StudentIdentityNumber!.Trim().ToLower()).ToList();

        var studentUsers = await _db.Users
            .Where(u => (u.StudentId.HasValue && studentIds.Contains(u.StudentId.Value)) || (u.Role == UserRole.Student && studentIdentities.Contains(u.Username.ToLower())))
            .ToListAsync();

        var studentUserMap = new Dictionary<int, string>();
        foreach (var s in students)
        {
            var matchedUser = studentUsers.FirstOrDefault(u => u.StudentId == s.Id)
                           ?? (!string.IsNullOrWhiteSpace(s.StudentIdentityNumber) ? studentUsers.FirstOrDefault(u => u.Username.Trim().ToLower() == s.StudentIdentityNumber.Trim().ToLower()) : null)
                           ?? studentUsers.FirstOrDefault(u => u.FullName.Trim().ToLower() == s.FullName.Trim().ToLower());
            if (matchedUser != null)
            {
                studentUserMap[s.Id] = matchedUser.Username;
                if (!matchedUser.StudentId.HasValue) matchedUser.StudentId = s.Id;
            }
        }

        var parentIds = students.Where(s => s.ParentId.HasValue).Select(s => s.ParentId!.Value).Distinct().ToList();
        var parentUsers = await _db.Users.Where(u => u.Role == UserRole.Parent && (parentIds.Contains(u.Id) || (u.ParentId.HasValue && parentIds.Contains(u.ParentId.Value)))).ToListAsync();
        var parentMap = parentUsers.ToDictionary(u => u.ParentId ?? u.Id, u => u.FullName);

        return students.Select(s => MapStudentToFullObject(
            s, 
            s.ParentId.HasValue && parentMap.TryGetValue(s.ParentId.Value, out var pName) ? pName : null,
            studentUserMap.TryGetValue(s.Id, out var uName) ? uName : s.StudentIdentityNumber
        )).ToList();
    }

    public static object MapStudentToFullObject(Student s, string? parentName = null, string? username = null) => new
    {
        s.Id,
        s.FullName,
        Username = username ?? s.StudentIdentityNumber,
        s.Address,
        s.FamilyContact,
        DateOfBirth = s.DateOfBirth.ToString("yyyy-MM-dd"),
        s.CircleId,
        CircleName = s.Circle?.Name ?? "غير مسند حلقة",
        TeacherId = s.Circle?.TeacherId,
        TeacherName = s.Circle?.Teacher?.FullName ?? "غير محدد",
        s.ParentId,
        ParentName = parentName ?? ExtractFatherName(s.FullName),
        RegistrationDate = s.RegistrationDate.ToString("yyyy-MM-dd"),
        s.IsActive,
        s.StudentIdentityNumber,
        s.PreviousQuranMemorization,
        s.StudentMobile,
        s.StudentWhatsapp,
        s.HealthStatus,
        s.FatherStatus,
        s.MotherStatus,
        s.Kinship,
        s.ParentIdentityNumber,
        s.WhatsappNumber,
        s.WalletNumber,
        s.BankAccountNumber,
        s.BankName,
        s.OriginalAddress,
        s.OriginalHousingType,
        s.OriginalHousingStatus,
        s.CurrentAddress,
        s.CurrentHousingType,
        s.Notes,
        s.PlanNotes,
        s.TargetAjzaaCount,
        s.PlanType,
        PlanStartDate = s.PlanStartDate?.ToString("yyyy-MM-dd"),
        PlanTargetDate = s.PlanTargetDate?.ToString("yyyy-MM-dd"),
        s.DailyPacePages,
        s.CompletedAjzaa
    };

    public async Task<Student?> GetByIdAsync(int id)
        => await _db.Students.Include(s => s.Circle).FirstOrDefaultAsync(s => s.Id == id);

    public async Task<object?> GetFullStudentByIdAsync(int id)
    {
        var s = await _db.Students.Include(s => s.Circle).FirstOrDefaultAsync(s => s.Id == id);
        if (s == null) return null;

        string? parentName = null;
        if (s.ParentId.HasValue)
        {
            var pUser = await _db.Users.FirstOrDefaultAsync(u => u.Role == UserRole.Parent && (u.Id == s.ParentId.Value || u.ParentId == s.ParentId.Value));
            if (pUser != null) parentName = pUser.FullName;
        }

        var stUser = await _db.Users.FirstOrDefaultAsync(u => u.StudentId == s.Id);
        if (stUser == null && !string.IsNullOrWhiteSpace(s.StudentIdentityNumber))
        {
            stUser = await _db.Users.FirstOrDefaultAsync(u => u.Username.ToLower() == s.StudentIdentityNumber.ToLower().Trim());
            if (stUser != null && !stUser.StudentId.HasValue)
            {
                stUser.StudentId = s.Id;
                await _db.SaveChangesAsync();
            }
        }
        if (stUser == null && !string.IsNullOrWhiteSpace(s.FullName))
        {
            stUser = await _db.Users.FirstOrDefaultAsync(u => u.Role == UserRole.Student && u.FullName.ToLower() == s.FullName.ToLower().Trim());
            if (stUser != null && !stUser.StudentId.HasValue)
            {
                stUser.StudentId = s.Id;
                await _db.SaveChangesAsync();
            }
        }

        if (stUser != null && !stUser.StudentId.HasValue)
        {
            stUser.StudentId = s.Id;
            try { await _db.SaveChangesAsync(); } catch { }
        }

        string? username = stUser?.Username ?? s.StudentIdentityNumber;

        return MapStudentToFullObject(s, parentName, username);
    }

    private static string ExtractFatherName(string fullName)
    {
        if (string.IsNullOrWhiteSpace(fullName)) return "الأب";
        var clean = fullName.Trim();
        string[] compoundPrefixes = new[] { "عبد الله", "عبد الرحمن", "عبد العزيز", "عبد القادر", "عبد الرحيم", "عبد السلام", "عبد المجيد", "عبد اللطيف", "عبد الوهاب", "عبد الكريم", "عبد الفتاح" };
        foreach (var prefix in compoundPrefixes)
        {
            if (clean.StartsWith(prefix + " ", StringComparison.OrdinalIgnoreCase))
            {
                var rest = clean.Substring(prefix.Length).Trim();
                if (!string.IsNullOrWhiteSpace(rest)) return rest;
            }
        }
        var parts = clean.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length >= 2)
        {
            return string.Join(" ", parts.Skip(1));
        }
        return "ولي أمر " + clean;
    }

    public async Task<(Student? created, User? createdParent, string? error)> CreateAsync(CreateStudentDto dto)
    {
        var err = Validate(dto.FullName, dto.FamilyContact, dto.DateOfBirth);
        if (err is not null) return (null, null, err);

        int? resolvedParentId = dto.ParentId;
        User? newlyCreatedParent = null;

        // Auto-search or link parent account (checks Teachers and existing Users by National ID)
        if (!resolvedParentId.HasValue && !string.IsNullOrWhiteSpace(dto.ParentIdentityNumber))
        {
            var pIdNum = dto.ParentIdentityNumber.Trim();
            var fatherName = !string.IsNullOrWhiteSpace(dto.ParentName) ? dto.ParentName.Trim() : ExtractFatherName(dto.FullName);

            // 1. Check if a Teacher exists with this IdentityNumber
            var matchedTeacher = await _db.Teachers.FirstOrDefaultAsync(t => t.IdentityNumber == pIdNum);
            if (matchedTeacher != null)
            {
                var teacherUser = await _db.Users.FirstOrDefaultAsync(u => u.TeacherId == matchedTeacher.Id || u.Username == pIdNum);
                if (teacherUser != null)
                {
                    teacherUser.ParentId = teacherUser.Id;
                    resolvedParentId = teacherUser.Id;
                    await _db.SaveChangesAsync();
                }
                else
                {
                    teacherUser = new User
                    {
                        Username = pIdNum,
                        PasswordHash = _hasher.HashPassword("123456"),
                        PlainPassword = "123456",
                        FullName = matchedTeacher.FullName,
                        Role = UserRole.Teacher,
                        TeacherId = matchedTeacher.Id,
                        IsActive = true
                    };
                    _db.Users.Add(teacherUser);
                    await _db.SaveChangesAsync();
                    teacherUser.ParentId = teacherUser.Id;
                    await _db.SaveChangesAsync();
                    resolvedParentId = teacherUser.Id;
                }
            }
            else
            {
                // 2. Check if a User already exists with this Username (any role: Parent, Admin, etc.)
                var existingUser = await _db.Users.FirstOrDefaultAsync(u => u.Username == pIdNum || (u.ParentId.HasValue && u.ParentId.ToString() == pIdNum));
                if (existingUser != null)
                {
                    if (!string.IsNullOrWhiteSpace(dto.ParentName) && existingUser.Role == UserRole.Parent)
                    {
                        existingUser.FullName = dto.ParentName.Trim();
                    }
                    if (!existingUser.ParentId.HasValue)
                    {
                        existingUser.ParentId = existingUser.Id;
                    }
                    resolvedParentId = existingUser.ParentId ?? existingUser.Id;
                    await _db.SaveChangesAsync();
                }
                else
                {
                    // 3. Check if any existing student has this parent identity number with a ParentId
                    var existingStudentWithParent = await _db.Students.FirstOrDefaultAsync(s => s.ParentIdentityNumber == pIdNum && s.ParentId != null);
                    if (existingStudentWithParent != null)
                    {
                        resolvedParentId = existingStudentWithParent.ParentId;
                    }
                    else
                    {
                        // 4. Create new Parent user
                        newlyCreatedParent = new User
                        {
                            Username = pIdNum,
                            PasswordHash = _hasher.HashPassword("123456"),
                            PlainPassword = "123456",
                            FullName = fatherName,
                            Role = UserRole.Parent,
                            IsActive = true
                        };
                        _db.Users.Add(newlyCreatedParent);
                        await _db.SaveChangesAsync();

                        newlyCreatedParent.ParentId = newlyCreatedParent.Id;
                        await _db.SaveChangesAsync();

                        resolvedParentId = newlyCreatedParent.Id;
                    }
                }
            }
        }

        var s = new Student
        {
            FullName = dto.FullName,
            Address = dto.Address ?? "",
            FamilyContact = dto.FamilyContact ?? "",
            DateOfBirth = dto.DateOfBirth ?? DateOnly.FromDateTime(DateTime.Today.AddYears(-10)),
            RegistrationDate = DateOnly.FromDateTime(DateTime.Today),
            CircleId = dto.CircleId,
            ParentId = resolvedParentId,
            IsActive = true,
            StudentIdentityNumber = dto.StudentIdentityNumber,
            PreviousQuranMemorization = dto.PreviousQuranMemorization,
            StudentMobile = dto.StudentMobile,
            StudentWhatsapp = dto.StudentWhatsapp,
            HealthStatus = dto.HealthStatus,
            FatherStatus = dto.FatherStatus,
            MotherStatus = dto.MotherStatus,
            Kinship = dto.Kinship,
            ParentIdentityNumber = dto.ParentIdentityNumber,
            WhatsappNumber = dto.WhatsappNumber,
            WalletNumber = dto.WalletNumber,
            BankAccountNumber = dto.BankAccountNumber,
            BankName = dto.BankName,
            OriginalAddress = dto.OriginalAddress,
            OriginalHousingType = dto.OriginalHousingType,
            OriginalHousingStatus = dto.OriginalHousingStatus,
            CurrentAddress = dto.CurrentAddress,
            CurrentHousingType = dto.CurrentHousingType,
            Notes = dto.Notes
        };
        _db.Students.Add(s);
        await _db.SaveChangesAsync();

        // Create or link Student User account
        string stUsername = !string.IsNullOrWhiteSpace(dto.Username) ? dto.Username.Trim() : (dto.StudentIdentityNumber?.Trim() ?? "");
        if (!string.IsNullOrWhiteSpace(stUsername))
        {
            var existingUser = await _db.Users.FirstOrDefaultAsync(u => u.Username.ToLower() == stUsername.ToLower());
            if (existingUser != null)
            {
                existingUser.StudentId = s.Id;
                existingUser.FullName = s.FullName;
                if (!string.IsNullOrWhiteSpace(dto.Password))
                {
                    existingUser.PasswordHash = _hasher.HashPassword(dto.Password.Trim());
                    existingUser.PlainPassword = dto.Password.Trim();
                }
            }
            else
            {
                string stPw = !string.IsNullOrWhiteSpace(dto.Password) ? dto.Password.Trim() : "123456";
                var stUser = new User
                {
                    Username = stUsername,
                    PasswordHash = _hasher.HashPassword(stPw),
                    PlainPassword = stPw,
                    FullName = s.FullName,
                    Role = UserRole.Student,
                    StudentId = s.Id,
                    IsActive = true
                };
                _db.Users.Add(stUser);
            }
            await _db.SaveChangesAsync();
        }

        return (s, newlyCreatedParent, null);
    }

    public async Task<(bool success, string? error)> UpdateAsync(int id, UpdateStudentDto dto)
    {
        var s = await _db.Students.FindAsync(id);
        if (s is null) return (false, "الطالب غير موجود.");

        if (!string.IsNullOrWhiteSpace(dto.FullName))
        {
            var err = Validate(dto.FullName, dto.FamilyContact ?? s.FamilyContact, dto.DateOfBirth ?? s.DateOfBirth);
            if (err is not null) return (false, err);
            s.FullName = dto.FullName.Trim();
        }

        if (dto.Address != null) s.Address = dto.Address.Trim();
        if (dto.FamilyContact != null) s.FamilyContact = dto.FamilyContact.Trim();
        if (dto.DateOfBirth.HasValue) s.DateOfBirth = dto.DateOfBirth.Value;
        
        // Always assign or unassign Circle
        s.CircleId = dto.CircleId;
        if (dto.IsActive.HasValue) s.IsActive = dto.IsActive.Value;

        if (dto.StudentIdentityNumber != null) s.StudentIdentityNumber = string.IsNullOrWhiteSpace(dto.StudentIdentityNumber) ? null : dto.StudentIdentityNumber.Trim();
        if (dto.PreviousQuranMemorization != null) s.PreviousQuranMemorization = string.IsNullOrWhiteSpace(dto.PreviousQuranMemorization) ? null : dto.PreviousQuranMemorization.Trim();
        if (dto.StudentMobile != null) s.StudentMobile = string.IsNullOrWhiteSpace(dto.StudentMobile) ? null : dto.StudentMobile.Trim();
        if (dto.StudentWhatsapp != null) s.StudentWhatsapp = string.IsNullOrWhiteSpace(dto.StudentWhatsapp) ? null : dto.StudentWhatsapp.Trim();
        if (dto.HealthStatus != null) s.HealthStatus = string.IsNullOrWhiteSpace(dto.HealthStatus) ? null : dto.HealthStatus.Trim();
        if (dto.FatherStatus != null) s.FatherStatus = string.IsNullOrWhiteSpace(dto.FatherStatus) ? null : dto.FatherStatus.Trim();
        if (dto.MotherStatus != null) s.MotherStatus = string.IsNullOrWhiteSpace(dto.MotherStatus) ? null : dto.MotherStatus.Trim();
        if (dto.Kinship != null) s.Kinship = string.IsNullOrWhiteSpace(dto.Kinship) ? null : dto.Kinship.Trim();
        if (dto.ParentIdentityNumber != null) s.ParentIdentityNumber = string.IsNullOrWhiteSpace(dto.ParentIdentityNumber) ? null : dto.ParentIdentityNumber.Trim();
        if (dto.WhatsappNumber != null) s.WhatsappNumber = string.IsNullOrWhiteSpace(dto.WhatsappNumber) ? null : dto.WhatsappNumber.Trim();
        if (dto.WalletNumber != null) s.WalletNumber = string.IsNullOrWhiteSpace(dto.WalletNumber) ? null : dto.WalletNumber.Trim();
        if (dto.BankAccountNumber != null) s.BankAccountNumber = string.IsNullOrWhiteSpace(dto.BankAccountNumber) ? null : dto.BankAccountNumber.Trim();
        if (dto.BankName != null) s.BankName = string.IsNullOrWhiteSpace(dto.BankName) ? null : dto.BankName.Trim();
        if (dto.OriginalAddress != null) s.OriginalAddress = string.IsNullOrWhiteSpace(dto.OriginalAddress) ? null : dto.OriginalAddress.Trim();
        if (dto.OriginalHousingType != null) s.OriginalHousingType = string.IsNullOrWhiteSpace(dto.OriginalHousingType) ? null : dto.OriginalHousingType.Trim();
        if (dto.OriginalHousingStatus != null) s.OriginalHousingStatus = string.IsNullOrWhiteSpace(dto.OriginalHousingStatus) ? null : dto.OriginalHousingStatus.Trim();
        if (dto.CurrentAddress != null) s.CurrentAddress = string.IsNullOrWhiteSpace(dto.CurrentAddress) ? null : dto.CurrentAddress.Trim();
        if (dto.CurrentHousingType != null) s.CurrentHousingType = string.IsNullOrWhiteSpace(dto.CurrentHousingType) ? null : dto.CurrentHousingType.Trim();
        
        // Notes: properly update or clear
        if (dto.Notes != null)
        {
            s.Notes = string.IsNullOrWhiteSpace(dto.Notes) ? null : dto.Notes.Trim();
        }

        if (dto.TargetAjzaaCount.HasValue && dto.TargetAjzaaCount.Value > 0) s.TargetAjzaaCount = dto.TargetAjzaaCount.Value;
        if (dto.PlanType != null) s.PlanType = dto.PlanType.Trim();
        if (dto.PlanStartDate.HasValue) s.PlanStartDate = dto.PlanStartDate.Value;
        if (dto.PlanTargetDate.HasValue) s.PlanTargetDate = dto.PlanTargetDate.Value;
        if (dto.DailyPacePages.HasValue && dto.DailyPacePages.Value > 0) s.DailyPacePages = dto.DailyPacePages.Value;
        if (dto.CompletedAjzaa != null) s.CompletedAjzaa = dto.CompletedAjzaa.Trim();

        int? resolvedParentId = dto.ParentId ?? s.ParentId;
        if (!string.IsNullOrWhiteSpace(dto.ParentIdentityNumber))
        {
            var pIdNum = dto.ParentIdentityNumber.Trim();
            var fatherName = !string.IsNullOrWhiteSpace(dto.ParentName) ? dto.ParentName.Trim() : ExtractFatherName(s.FullName);

            // 1. Check if a Teacher exists with this IdentityNumber
            var matchedTeacher = await _db.Teachers.FirstOrDefaultAsync(t => t.IdentityNumber == pIdNum);
            if (matchedTeacher != null)
            {
                var teacherUser = await _db.Users.FirstOrDefaultAsync(u => u.TeacherId == matchedTeacher.Id || u.Username == pIdNum);
                if (teacherUser != null)
                {
                    teacherUser.ParentId = teacherUser.Id;
                    resolvedParentId = teacherUser.Id;
                    await _db.SaveChangesAsync();
                }
                else
                {
                    teacherUser = new User
                    {
                        Username = pIdNum,
                        PasswordHash = _hasher.HashPassword("123456"),
                        PlainPassword = "123456",
                        FullName = matchedTeacher.FullName,
                        Role = UserRole.Teacher,
                        TeacherId = matchedTeacher.Id,
                        IsActive = true
                    };
                    _db.Users.Add(teacherUser);
                    await _db.SaveChangesAsync();
                    teacherUser.ParentId = teacherUser.Id;
                    await _db.SaveChangesAsync();
                    resolvedParentId = teacherUser.Id;
                }
            }
            else
            {
                // 2. Check if a User already exists with this Username (any role: Parent, Admin, etc.)
                var existingUser = await _db.Users.FirstOrDefaultAsync(u => u.Username == pIdNum || (u.ParentId.HasValue && u.ParentId.ToString() == pIdNum));
                if (existingUser != null)
                {
                    if (!string.IsNullOrWhiteSpace(dto.ParentName) && existingUser.Role == UserRole.Parent)
                    {
                        existingUser.FullName = dto.ParentName.Trim();
                    }
                    if (!existingUser.ParentId.HasValue)
                    {
                        existingUser.ParentId = existingUser.Id;
                    }
                    resolvedParentId = existingUser.ParentId ?? existingUser.Id;
                    await _db.SaveChangesAsync();
                }
                else
                {
                    // 3. Check if any other student has this ParentIdentityNumber with a ParentId
                    var otherStudentWithParent = await _db.Students.FirstOrDefaultAsync(st => st.Id != s.Id && st.ParentIdentityNumber == pIdNum && st.ParentId != null);
                    if (otherStudentWithParent != null)
                    {
                        resolvedParentId = otherStudentWithParent.ParentId;
                    }
                    else
                    {
                        // 4. Create new Parent user
                        var newParent = new User
                        {
                            Username = pIdNum,
                            PasswordHash = _hasher.HashPassword("123456"),
                            PlainPassword = "123456",
                            FullName = fatherName,
                            Role = UserRole.Parent,
                            IsActive = true
                        };
                        _db.Users.Add(newParent);
                        await _db.SaveChangesAsync();

                        newParent.ParentId = newParent.Id;
                        await _db.SaveChangesAsync();

                        resolvedParentId = newParent.Id;
                    }
                }
            }
        }
        else if (!string.IsNullOrWhiteSpace(dto.ParentName) && s.ParentId.HasValue)
        {
            var pUser = await _db.Users.FirstOrDefaultAsync(u => u.Id == s.ParentId.Value || u.ParentId == s.ParentId.Value);
            if (pUser != null)
            {
                pUser.FullName = dto.ParentName.Trim();
            }
        }

        s.ParentId = resolvedParentId;

        // Update or create linked Student User
        string? customUsername = !string.IsNullOrWhiteSpace(dto.Username) ? dto.Username.Trim() : null;
        var studentUser = await _db.Users.FirstOrDefaultAsync(u => u.StudentId == s.Id);
        if (studentUser == null && !string.IsNullOrWhiteSpace(s.StudentIdentityNumber))
        {
            studentUser = await _db.Users.FirstOrDefaultAsync(u => u.Username.ToLower() == s.StudentIdentityNumber.ToLower().Trim());
        }
        if (studentUser == null && customUsername != null)
        {
            studentUser = await _db.Users.FirstOrDefaultAsync(u => u.Username.ToLower() == customUsername.ToLower());
        }
        if (studentUser == null && !string.IsNullOrWhiteSpace(s.FullName))
        {
            studentUser = await _db.Users.FirstOrDefaultAsync(u => u.Role == UserRole.Student && u.FullName.ToLower() == s.FullName.ToLower().Trim());
        }

        if (studentUser != null)
        {
            studentUser.StudentId = s.Id;
            studentUser.Role = UserRole.Student;

            if (customUsername != null && customUsername.ToLower() != studentUser.Username.ToLower())
            {
                var taken = await _db.Users.AnyAsync(u => u.Id != studentUser.Id && u.Username.ToLower() == customUsername.ToLower());
                if (taken) return (false, "اسم المستخدم محجوز بالفعل لمستخدم أو طالب آخر.");
                studentUser.Username = customUsername;
            }
            studentUser.FullName = s.FullName;
            if (dto.IsActive.HasValue) studentUser.IsActive = dto.IsActive.Value;
            if (!string.IsNullOrWhiteSpace(dto.Password))
            {
                studentUser.PasswordHash = _hasher.HashPassword(dto.Password.Trim());
                studentUser.PlainPassword = dto.Password.Trim();
            }
        }
        else if (customUsername != null || !string.IsNullOrWhiteSpace(s.StudentIdentityNumber))
        {
            string finalUName = customUsername ?? s.StudentIdentityNumber!.Trim();
            var taken = await _db.Users.AnyAsync(u => u.Username.ToLower() == finalUName.ToLower());
            if (taken) return (false, "اسم المستخدم محجوز بالفعل لمستخدم أو طالب آخر.");

            string finalPw = !string.IsNullOrWhiteSpace(dto.Password) ? dto.Password.Trim() : "123456";
            var newStUser = new User
            {
                Username = finalUName,
                PasswordHash = _hasher.HashPassword(finalPw),
                PlainPassword = finalPw,
                FullName = s.FullName,
                Role = UserRole.Student,
                StudentId = s.Id,
                IsActive = dto.IsActive ?? true
            };
            _db.Users.Add(newStUser);
        }

        try
        {
            await _db.SaveChangesAsync();
            return (true, null);
        }
        catch (Exception ex)
        {
            return (false, $"حدث خطأ في قاعدة البيانات أثناء حفظ بيانات الطالب: {ex.Message}");
        }
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var s = await _db.Students.FindAsync(id);
        if (s is null) return false;
        s.IsActive = false;
        await _db.SaveChangesAsync();
        return true;
    }

    public Task<bool> DeactivateAsync(int id) => DeleteAsync(id);

    public async Task<(bool success, string studentName, string message)> HardDeleteAsync(int id)
    {
        var s = await _db.Students.FindAsync(id);
        if (s is null) return (false, "", "الطالب غير موجود.");

        var studentName = s.FullName;
        var parentId = s.ParentId;

        // Remove linked recitation sessions
        var recSessions = await _db.Sessions.Where(r => r.StudentId == id).ToListAsync();
        _db.Sessions.RemoveRange(recSessions);

        // Remove attendance records
        var attendances = await _db.Attendances.Where(a => a.StudentId == id).ToListAsync();
        _db.Attendances.RemoveRange(attendances);

        // Remove course enrollments and course attendances
        var enrollments = await _db.CourseEnrollments.Where(ce => ce.StudentId == id).ToListAsync();
        _db.CourseEnrollments.RemoveRange(enrollments);

        var courseAtts = await _db.CourseAttendances.Where(ca => ca.StudentId == id).ToListAsync();
        _db.CourseAttendances.RemoveRange(courseAtts);

        // Remove exam nominations
        var examNoms = await _db.ExamNominations.Where(e => e.StudentId == id).ToListAsync();
        _db.ExamNominations.RemoveRange(examNoms);

        // Remove profile update requests
        var reqs = await _db.ProfileUpdateRequests.Where(r => r.StudentId == id).ToListAsync();
        _db.ProfileUpdateRequests.RemoveRange(reqs);

        // Remove Student User if present
        var stUser = await _db.Users.FirstOrDefaultAsync(u => u.StudentId == id);
        if (stUser != null) _db.Users.Remove(stUser);

        // Remove Student entity
        _db.Students.Remove(s);

        // Clean parent user if parent user has no other students
        if (parentId.HasValue)
        {
            var otherStudentsCount = await _db.Students.CountAsync(st => st.Id != id && st.ParentId == parentId.Value);
            if (otherStudentsCount == 0)
            {
                var parentUser = await _db.Users.FirstOrDefaultAsync(u => u.ParentId == parentId.Value);
                if (parentUser != null)
                {
                    _db.Users.Remove(parentUser);
                }
            }
        }

        await _db.SaveChangesAsync();
        return (true, studentName, "تم حذف الطالب وحساباته وسجلاته نهائياً بالكامل.");
    }

    public async Task<(bool success, bool isActive, string message)> ToggleActiveAsync(int id)
    {
        var s = await _db.Students.FindAsync(id);
        if (s is null) return (false, false, "الطالب غير موجود.");

        s.IsActive = !s.IsActive;
        await _db.SaveChangesAsync();

        return (true, s.IsActive, s.IsActive ? "تم تنشيط الطالب بنجاح." : "تم تعطيل الطالب بنجاح.");
    }

    public async Task<(object? progress, string? error)> GetStudentProgressByIdAsync(int studentId)
    {
        var s = await _db.Students.Include(x => x.Circle).FirstOrDefaultAsync(x => x.Id == studentId);
        return s is null ? (null, "الطالب غير موجود.") : (await BuildProgressAsync(s), null);
    }

    public async Task<(object? progress, string? error)> GetStudentProgressByUserIdAsync(int userId)
    {
        var u = await _db.Users.FindAsync(userId);
        if (u is null) return (null, "حساب الطالب غير صريح.");

        Student? s = null;
        if (u.StudentId.HasValue)
        {
            s = await _db.Students.Include(x => x.Circle).FirstOrDefaultAsync(x => x.Id == u.StudentId.Value);
        }

        if (s == null)
        {
            s = await _db.Students.Include(x => x.Circle).FirstOrDefaultAsync(x =>
                (!string.IsNullOrWhiteSpace(x.StudentIdentityNumber) && x.StudentIdentityNumber.Trim().ToLower() == u.Username.ToLower().Trim()) ||
                x.FullName.Trim().ToLower() == u.FullName.ToLower().Trim());

            if (s != null)
            {
                u.StudentId = s.Id;
                await _db.SaveChangesAsync();
            }
        }

        if (s is null) return (null, "الطالب غير موجود.");

        if (s.FullName != u.FullName && !string.IsNullOrWhiteSpace(u.FullName))
        {
            s.FullName = u.FullName;
            try { await _db.SaveChangesAsync(); } catch { }
        }

        return (await BuildProgressAsync(s), null);
    }

    private async Task<object> BuildProgressAsync(Student s)
    {
        var sessions = await _db.Sessions
            .Where(x => x.StudentId == s.Id)
            .OrderByDescending(x => x.SessionDate)
            .ToListAsync();

        var attendances = await _db.Attendances
            .Where(x => x.StudentId == s.Id)
            .OrderByDescending(x => x.SessionDate)
            .ToListAsync();

        int presentCount = attendances.Count(a => a.Status == AttendanceStatus.Present);
        int absentCount = attendances.Count(a => a.Status == AttendanceStatus.Absent);
        int lateCount = attendances.Count(a => a.Status == AttendanceStatus.Late);
        int total = attendances.Count;
        double rate = total == 0 ? 100.0 : Math.Round((double)presentCount / total * 100.0, 1);

        var sessionsDto = sessions.Select(sess => new
        {
            sess.Id,
            sess.StudentId,
            sess.SurahName,
            sess.FromVerse,
            sess.ToVerse,
            Assessment = sess.Assessment.ToString(),
            sess.Notes,
            sess.ViaLottery,
            SessionDate = sess.SessionDate.ToString("yyyy-MM-dd")
        }).ToList();

        var attendancesDto = attendances.Select(att => new
        {
            att.Id,
            att.StudentId,
            att.CircleId,
            CircleName = s.Circle?.Name ?? "حلقة التحفيظ",
            SessionDate = att.SessionDate.ToString("yyyy-MM-dd"),
            Status = (int)att.Status,
            StatusText = att.Status == AttendanceStatus.Present ? "حاضر" : (att.Status == AttendanceStatus.Absent ? "غائب" : "متأخر")
        }).ToList();

        var courseAttendances = await _db.CourseAttendances
            .Include(ca => ca.Course)
            .Where(ca => ca.StudentId == s.Id)
            .OrderByDescending(ca => ca.SessionDate)
            .ToListAsync();

        var courseAttendancesDto = courseAttendances.Select(ca => new {
            ca.Id,
            ca.CourseId,
            CourseName = ca.Course?.Name ?? "مساق تعليمي",
            SessionDate = ca.SessionDate.ToString("yyyy-MM-dd"),
            Status = (int)ca.Status,
            StatusText = ca.Status == AttendanceStatus.Present ? "حاضر" : (ca.Status == AttendanceStatus.Absent ? "غائب" : "متأخر")
        }).ToList();

        var exams = await _db.ExamNominations
            .Include(x => x.Result)
            .Include(x => x.Teacher)
            .Include(x => x.Course)
            .Where(x => x.StudentId == s.Id && x.Status == "Completed")
            .OrderByDescending(x => x.ExamDate)
            .ToListAsync();

        string teacherName = "غير مسند";
        if (s.CircleId.HasValue && s.Circle != null && s.Circle.TeacherId > 0)
        {
            var teacher = await _db.Teachers.FindAsync(s.Circle.TeacherId);
            if (teacher != null) teacherName = teacher.FullName;
        }

        var passedCourses = await _db.CourseEnrollments
            .Include(ce => ce.Course)
                .ThenInclude(c => c!.Teacher)
            .Where(ce => ce.StudentId == s.Id && ce.Status == "Passed")
            .OrderByDescending(ce => ce.CertificateDate ?? ce.EnrollmentDate)
            .ToListAsync();

        var passedCourseIds = passedCourses.Select(pc => pc.CourseId).ToHashSet();

        // Include Quran exams, and course exams ONLY if not already represented in passedCourses
        var examCerts = exams
            .Where(e => e.NominationType == "Quran" || !e.CourseId.HasValue || !passedCourseIds.Contains(e.CourseId.Value))
            .Select(e => {
                var isQuran = e.NominationType == "Quran";
                var exYear = e.ExamDate?.Year ?? DateTime.Today.Year;
                var exMonth = e.ExamDate?.Month ?? DateTime.Today.Month;
                var certCode = isQuran
                    ? $"CERT-Q-{exYear}{exMonth:00}-{1000 + e.Id}"
                    : $"CERT-C-{exYear}{exMonth:00}-{1000 + e.Id}";

                return new {
                    e.Id,
                    e.StudentId,
                    StudentName = s.FullName,
                    e.NominationType,
                    CourseId = e.CourseId,
                    CourseName = e.Course?.Name ?? (isQuran ? (e.JuzStart == e.JuzEnd ? $"حفظ الجزء ({e.JuzStart})" : $"حفظ الأجزاء ({e.JuzStart} - {e.JuzEnd})") : "مساق ودورة شرعية"),
                    TeacherName = e.Teacher?.FullName ?? teacherName,
                    JuzStart = e.JuzStart,
                    JuzEnd = e.JuzEnd,
                    FormattedDetails = isQuran ? (e.JuzStart == e.JuzEnd ? $"حفظ الجزء ({e.JuzStart})" : $"حفظ الأجزاء ({e.JuzStart} - {e.JuzEnd})") : (e.Course?.Name ?? "مساق ودورة شرعية"),
                    Grade = e.Result?.Grade ?? 100.0,
                    ExamDate = e.ExamDate?.ToString("yyyy-MM-dd") ?? e.NominationDate.ToString("yyyy-MM-dd"),
                    CertificateCode = certCode,
                    CertificateDate = e.ExamDate?.ToString("yyyy-MM-dd") ?? DateTime.Today.ToString("yyyy-MM-dd")
                };
            }).ToList();

        var courseCerts = passedCourses.Select(pc => {
            var certYear = pc.CertificateDate?.Year ?? pc.EnrollmentDate.Year;
            var certMonth = pc.CertificateDate?.Month ?? pc.EnrollmentDate.Month;
            var certCode = !string.IsNullOrWhiteSpace(pc.CertificateCode)
                ? pc.CertificateCode
                : $"CERT-{certYear}{certMonth:00}-{1000 + pc.Id}";

            return new {
                Id = 10000 + pc.Id,
                pc.StudentId,
                StudentName = s.FullName,
                NominationType = "Course",
                CourseId = (int?)pc.CourseId,
                CourseName = pc.Course?.Name ?? "دورة معتمدة",
                TeacherName = pc.Course?.Teacher?.FullName ?? teacherName,
                JuzStart = (int?)null,
                JuzEnd = (int?)null,
                FormattedDetails = $"دورة: {pc.Course?.Name ?? "مساق معتمد"}",
                Grade = pc.Grade.HasValue ? (double)pc.Grade.Value : 90.0,
                ExamDate = pc.CertificateDate?.ToString("yyyy-MM-dd") ?? pc.EnrollmentDate.ToString("yyyy-MM-dd"),
                CertificateCode = certCode,
                CertificateDate = pc.CertificateDate?.ToString("yyyy-MM-dd") ?? DateTime.Today.ToString("yyyy-MM-dd")
            };
        }).ToList();

        var allCompletedCerts = examCerts.Concat(courseCerts).OrderByDescending(c => c.ExamDate).ToList();

        var talents = await _db.TalentRecords
            .Include(t => t.SupervisorTeacher)
            .Where(t => t.StudentId == s.Id)
            .OrderByDescending(t => t.EventDate)
            .ToListAsync();

        var talentsDto = talents.Select(t => new {
            t.Id,
            t.TalentType,
            t.Title,
            t.PreparationMethod,
            t.SpeechContent,
            t.Occasion,
            EventDate = t.EventDate.ToString("yyyy-MM-dd"),
            t.SupervisorTeacherId,
            SupervisorTeacherName = t.SupervisorTeacher?.FullName ?? "غير معين",
            t.MediaUrl,
            t.MediaType,
            t.EvaluationScore,
            t.PerformanceNotes
        }).ToList();

        var settings = await _db.SystemSettings.FirstOrDefaultAsync() ?? new SystemSettings();
        int passingScore = settings.PassingScoreThreshold > 0 ? settings.PassingScoreThreshold : 70;

        var juzStatus = new Dictionary<int, string>();
        for (int i = 1; i <= 30; i++)
        {
            var passedExam = exams.FirstOrDefault(e => e.NominationType == "Quran" && i >= e.JuzStart && i <= e.JuzEnd && (e.Status == "Completed" || e.Result?.Grade >= passingScore));
            if (passedExam != null)
            {
                juzStatus[i] = "Completed";
            }
            else
            {
                var pendingExam = await _db.ExamNominations.FirstOrDefaultAsync(e => e.StudentId == s.Id && e.NominationType == "Quran" && i >= e.JuzStart && i <= e.JuzEnd);
                if (pendingExam != null)
                {
                    juzStatus[i] = pendingExam.Status == "Scheduled" ? "Scheduled" : "Pending";
                }
                else
                {
                    juzStatus[i] = "NotStarted";
                }
            }
        }

        return new
        {
            StudentId = s.Id,
            StudentName = s.FullName,
            s.StudentIdentityNumber,
            s.PreviousQuranMemorization,
            s.StudentMobile,
            s.StudentWhatsapp,
            s.HealthStatus,
            s.FatherStatus,
            s.MotherStatus,
            s.Kinship,
            s.ParentIdentityNumber,
            s.WhatsappNumber,
            s.WalletNumber,
            s.BankAccountNumber,
            s.BankName,
            s.OriginalAddress,
            s.OriginalHousingType,
            s.OriginalHousingStatus,
            s.CurrentAddress,
            s.CurrentHousingType,
            s.Notes,
            s.PlanNotes,
            CircleName = s.Circle?.Name ?? "غير مسند",
            TeacherName = teacherName,
            TargetAjzaa = s.TargetAjzaaCount,
            TargetAjzaaCount = s.TargetAjzaaCount,
            PlanType = s.PlanType ?? "Standard",
            DailyPacePages = s.DailyPacePages,
            PlanStartDate = s.PlanStartDate?.ToString("yyyy-MM-dd"),
            PlanTargetDate = s.PlanTargetDate?.ToString("yyyy-MM-dd"),
            CompletedAjzaa = s.CompletedAjzaa ?? "",
            AttendanceRatePercentage = rate,
            AttendanceRate = rate,
            PresentDaysCount = presentCount,
            PresentDays = presentCount,
            PresentCount = presentCount,
            AbsentDaysCount = absentCount,
            AbsentDays = absentCount,
            AbsentCount = absentCount,
            LateDaysCount = lateCount,
            LateDays = lateCount,
            LateCount = lateCount,
            TotalDays = total,
            CertificatesCount = allCompletedCerts.Count,
            Sessions = sessionsDto,
            AttendanceHistory = attendancesDto,
            CenterAttendance = attendancesDto,
            CourseAttendance = courseAttendancesDto,
            CompletedExams = allCompletedCerts,
            Talents = talentsDto,
            IsTalented = talentsDto.Count > 0,
            JuzStatus = juzStatus,
            StudentInfo = new
            {
                Id = s.Id,
                FullName = s.FullName,
                StudentName = s.FullName,
                CircleName = s.Circle?.Name ?? "غير مسند",
                TeacherName = teacherName,
                FamilyContact = s.FamilyContact,
                StudentMobile = s.StudentMobile,
                StudentWhatsapp = s.StudentWhatsapp,
                StudentIdentityNumber = s.StudentIdentityNumber,
                PreviousQuranMemorization = s.PreviousQuranMemorization,
                TargetAjzaaCount = s.TargetAjzaaCount,
                PlanType = s.PlanType ?? "Standard",
                DailyPacePages = s.DailyPacePages,
                PlanStartDate = s.PlanStartDate?.ToString("yyyy-MM-dd"),
                PlanTargetDate = s.PlanTargetDate?.ToString("yyyy-MM-dd"),
                CompletedAjzaa = s.CompletedAjzaa ?? "",
                Notes = s.Notes,
                PlanNotes = s.PlanNotes
            },
            RecentSessions = sessionsDto
        };
    }

    private static string? Validate(string fullName, string? contact, DateOnly? dob)
    {
        if (string.IsNullOrWhiteSpace(fullName)) return "اسم الطالب مطلوب.";
        return null;
    }
}
