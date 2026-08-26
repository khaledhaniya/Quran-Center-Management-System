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
        var query = _db.Students.Include(s => s.Circle).AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim().ToLower();
            query = query.Where(s => s.FullName.ToLower().Contains(q)
                || (s.Circle != null && s.Circle.Name.ToLower().Contains(q)));
        }

        var students = await query.OrderBy(s => s.Id).ToListAsync();
        var parentIds = students.Where(s => s.ParentId.HasValue).Select(s => s.ParentId!.Value).Distinct().ToList();
        var parentUsers = await _db.Users.Where(u => u.Role == UserRole.Parent && (parentIds.Contains(u.Id) || (u.ParentId.HasValue && parentIds.Contains(u.ParentId.Value)))).ToListAsync();
        var parentMap = parentUsers.ToDictionary(u => u.ParentId ?? u.Id, u => u.FullName);

        return students.Select(s => MapStudentToFullObject(s, s.ParentId.HasValue && parentMap.TryGetValue(s.ParentId.Value, out var pName) ? pName : null)).ToList();
    }

    public async Task<List<object>> GetStudentsForTeacherAsync(int teacherId, string? search)
    {
        var query = _db.Students.Include(s => s.Circle).AsQueryable();

        query = query.Where(s => (s.Circle != null && s.Circle.TeacherId == teacherId)
            || _db.CourseEnrollments.Any(ce => ce.StudentId == s.Id && ce.Course != null && ce.Course.TeacherId == teacherId));

        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim().ToLower();
            query = query.Where(s => s.FullName.ToLower().Contains(q)
                || (s.Circle != null && s.Circle.Name.ToLower().Contains(q)));
        }

        var students = await query.OrderBy(s => s.Id).ToListAsync();
        var parentIds = students.Where(s => s.ParentId.HasValue).Select(s => s.ParentId!.Value).Distinct().ToList();
        var parentUsers = await _db.Users.Where(u => u.Role == UserRole.Parent && (parentIds.Contains(u.Id) || (u.ParentId.HasValue && parentIds.Contains(u.ParentId.Value)))).ToListAsync();
        var parentMap = parentUsers.ToDictionary(u => u.ParentId ?? u.Id, u => u.FullName);

        return students.Select(s => MapStudentToFullObject(s, s.ParentId.HasValue && parentMap.TryGetValue(s.ParentId.Value, out var pName) ? pName : null)).ToList();
    }

    public static object MapStudentToFullObject(Student s, string? parentName = null) => new
    {
        s.Id,
        s.FullName,
        s.Address,
        s.FamilyContact,
        DateOfBirth = s.DateOfBirth.ToString("yyyy-MM-dd"),
        s.CircleId,
        CircleName = s.Circle?.Name ?? "غير مسند حلقة",
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
        s.Notes
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

        return MapStudentToFullObject(s, parentName);
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

        // Auto-search or create parent account if parentId is not explicitly set
        if (!resolvedParentId.HasValue && !string.IsNullOrWhiteSpace(dto.ParentIdentityNumber))
        {
            var pIdNum = dto.ParentIdentityNumber.Trim();
            var fatherName = !string.IsNullOrWhiteSpace(dto.ParentName) ? dto.ParentName.Trim() : ExtractFatherName(dto.FullName);

            var existingParent = await _db.Users.FirstOrDefaultAsync(u => u.Role == UserRole.Parent && (u.Username == pIdNum || u.ParentId.ToString() == pIdNum));
            if (existingParent != null)
            {
                if (!string.IsNullOrWhiteSpace(dto.ParentName))
                {
                    existingParent.FullName = dto.ParentName.Trim();
                    await _db.SaveChangesAsync();
                }
                resolvedParentId = existingParent.ParentId ?? existingParent.Id;
            }
            else
            {
                // Check if any existing student has this parent identity number with a ParentId
                var existingStudentWithParent = await _db.Students.FirstOrDefaultAsync(s => s.ParentIdentityNumber == pIdNum && s.ParentId != null);
                if (existingStudentWithParent != null)
                {
                    resolvedParentId = existingStudentWithParent.ParentId;
                }
                else
                {
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

        if (!string.IsNullOrWhiteSpace(dto.Address)) s.Address = dto.Address.Trim();
        if (!string.IsNullOrWhiteSpace(dto.FamilyContact)) s.FamilyContact = dto.FamilyContact.Trim();
        if (dto.DateOfBirth.HasValue) s.DateOfBirth = dto.DateOfBirth.Value;
        
        s.CircleId = dto.CircleId;
        s.IsActive = dto.IsActive;

        s.StudentIdentityNumber = dto.StudentIdentityNumber;
        s.PreviousQuranMemorization = dto.PreviousQuranMemorization;
        s.StudentMobile = dto.StudentMobile;
        s.StudentWhatsapp = dto.StudentWhatsapp;
        s.HealthStatus = dto.HealthStatus;
        s.FatherStatus = dto.FatherStatus;
        s.MotherStatus = dto.MotherStatus;
        s.Kinship = dto.Kinship;
        s.ParentIdentityNumber = dto.ParentIdentityNumber;
        s.WhatsappNumber = dto.WhatsappNumber;
        s.WalletNumber = dto.WalletNumber;
        s.BankAccountNumber = dto.BankAccountNumber;
        s.BankName = dto.BankName;
        s.OriginalAddress = dto.OriginalAddress;
        s.OriginalHousingType = dto.OriginalHousingType;
        s.OriginalHousingStatus = dto.OriginalHousingStatus;
        s.CurrentAddress = dto.CurrentAddress;
        s.CurrentHousingType = dto.CurrentHousingType;
        s.Notes = dto.Notes;

        int? resolvedParentId = dto.ParentId ?? s.ParentId;
        if (!string.IsNullOrWhiteSpace(dto.ParentIdentityNumber))
        {
            var pIdNum = dto.ParentIdentityNumber.Trim();
            var fatherName = !string.IsNullOrWhiteSpace(dto.ParentName) ? dto.ParentName.Trim() : ExtractFatherName(dto.FullName);

            var existingParent = await _db.Users.FirstOrDefaultAsync(u => u.Role == UserRole.Parent && (u.Username == pIdNum || u.ParentId.ToString() == pIdNum));
            if (existingParent != null)
            {
                if (!string.IsNullOrWhiteSpace(dto.ParentName))
                {
                    existingParent.FullName = dto.ParentName.Trim();
                }
                resolvedParentId = existingParent.ParentId ?? existingParent.Id;
            }
            else
            {
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
                resolvedParentId = newParent.Id;
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

        // Also update linked Student User full name if exists
        var studentUser = await _db.Users.FirstOrDefaultAsync(u => u.StudentId == s.Id);
        if (studentUser != null)
        {
            studentUser.FullName = dto.FullName;
        }

        await _db.SaveChangesAsync();
        return (true, null);
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
        if (u is null || u.StudentId is null) return (null, "حساب الطالب غير صريح.");

        var s = await _db.Students.Include(x => x.Circle).FirstOrDefaultAsync(x => x.Id == u.StudentId.Value);
        return s is null ? (null, "الطالب غير موجود.") : (await BuildProgressAsync(s), null);
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
            .Where(x => x.StudentId == s.Id && x.Status == "Completed")
            .OrderByDescending(x => x.ExamDate)
            .ToListAsync();

        var completedExamsDto = exams.Select(e => new {
            e.Id,
            e.StudentId,
            StudentName = s.FullName,
            e.NominationType,
            FormattedDetails = e.NominationType == "Quran" ? $"أجزاء قرآن كريم ({e.JuzStart} - {e.JuzEnd})" : "مساق ودورة شرعية",
            Grade = e.Result?.Grade ?? 100,
            ExamDate = e.ExamDate?.ToString("yyyy-MM-dd") ?? e.NominationDate.ToString("yyyy-MM-dd")
        }).ToList();

        var juzStatus = new Dictionary<int, string>();
        for (int i = 1; i <= 30; i++)
        {
            var passedExam = exams.FirstOrDefault(e => e.NominationType == "Quran" && i >= e.JuzStart && i <= e.JuzEnd && e.Result?.Grade >= 60);
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

        string teacherName = "غير مسند";
        if (s.CircleId.HasValue && s.Circle != null && s.Circle.TeacherId > 0)
        {
            var teacher = await _db.Teachers.FindAsync(s.Circle.TeacherId);
            if (teacher != null) teacherName = teacher.FullName;
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
            CircleName = s.Circle?.Name ?? "غير مسند",
            TeacherName = teacherName,
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
            CertificatesCount = completedExamsDto.Count,
            Sessions = sessionsDto,
            AttendanceHistory = attendancesDto,
            CenterAttendance = attendancesDto,
            CourseAttendance = courseAttendancesDto,
            CompletedExams = completedExamsDto,
            JuzStatus = juzStatus
        };
    }

    private static string? Validate(string fullName, string? contact, DateOnly? dob)
    {
        if (string.IsNullOrWhiteSpace(fullName)) return "اسم الطالب مطلوب.";
        return null;
    }
}
