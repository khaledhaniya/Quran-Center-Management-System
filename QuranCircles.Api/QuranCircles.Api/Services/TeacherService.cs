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
        if (!await _db.Teachers.AnyAsync())
        {
            await ImportExcelTeachersAsync();
        }

        var q = _db.Teachers.AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(t => t.FullName.Contains(search));
        return await q.Select(t => Map(t)).ToListAsync();
    }

    public async Task<(int imported, int updated, string? error)> ImportExcelTeachersAsync()
    {
        var excelTeachers = new List<(string FullName, string IdNum, string Dob, string Mobile, string Whatsapp, string SocialStatus, int? FamilyCount, string Mosque, string Qualification, string TaskRole, string WalletNum, string WalletOwner, string Memorized, string StudentsTarget)>
        {
            ("علي حسن أحمد النبيه", "408118297", "2002-06-12", "592479669", "00972592479669", "أعزب", 7, "علي بن أبي طالب", "خريج بكالوريوس IT", "مركز البيان", "592479669", "بنك/ علي حسن النبيه", "14", "-"),
            ("أحمد صلاح عطالله عياد", "401818398", "1996-07-20", "592687759", "00972567180837", "متزوج", 4, "علي بن أبي طالب", "دبلوم محاسبة", "الملف المالي + معلم دورات", "568570600", "أحمد صلاح عياد", "3", "-"),
            ("حسن عدنان سعيد حسونة", "800628752", "1986-12-13", "592612615", "00970595939297", "متزوج", 5, "علي بن أبي طالب", "", "معلم دورات", "592612615", "حسن عدنان حسونة", "", ""),
            ("محمود حسن أحمد النبيه", "803495829", "1991-04-12", "597240738", "00972597240738", "متزوج", 5, "علي بن أبي طالب", "ماجستير إدارة أعمال", "الجودة + السنة والتفسير", "597240738", "محمود حسن النبيه", "القرآن كاملاً", "-"),
            ("محمد نافذ فايق عزام", "804516573", "1993-12-12", "597994127", "", "أعزب", 5, "علي بن أبي طالب", "بكالوريوس شريعة وقانون", "التحفيظ + ملف منتدى الحفاظ", "599594676", "فايق نافذ عزام", "القرآن كاملاً", ""),
            ("بلال حماد سلمان لباد", "804696441", "1994-03-25", "597401718", "00972592578587", "متزوج", 3, "علي بن أبي طالب", "خريج بكالوريوس تجارة", "الدورات + معلم حلقة", "597401718", "بلال حماد لباد", "القرآن كاملاً", ""),
            ("جهاد مصطفى محمود الهجين", "802133165", "1988-11-01", "595974047", "00972595674047", "متزوج", 6, "علي بن أبي طالب", "ماجستير رياضيات", "معلم دورات", "567894299", "جهاد مصطفى الهجين", "5", "-"),
            ("محمد حسام محمد السويسي", "400146486", "1994-02-11", "567882318", "00972592766996", "أعزب", 6, "علي بن أبي طالب", "ثانوي", "مساعد حلقة + الفتى الواعظ + الأصوات الندية", "567882318", "محمد حسام السويسي", "10", "-"),
            ("محمود مصطفى حامد فروانة", "408485316", "2003-04-09", "592440564", "00972592440564", "أعزب", 3, "علي بن أبي طالب", "دبلوم IT", "معلم حلقة", "599903506", "بنك/ بدرية فروانة", "القران كاملاً", ""),
            ("محمد بسام محمد مرتجى", "429507023", "2010-02-17", "597669548", "00972597669548", "أعزب", 6, "علي بن أبي طالب", "طالب ثانوي", "معلم حلقة", "592520423", "نور سعيد مرتجى", "القران كاملاً", ""),
            ("محمد فوزي فايق عزام", "406086553", "2000-05-09", "597025601", "00972597025601", "أعزب", 5, "علي بن أبي طالب", "توجيهي", "معلم حلقة", "597243562", "شريفه محمود عزام", "القران كاملاً", ""),
            ("ابراهيم محمد سليم عزام", "403243900", "1997-11-14", "592525761", "00972592525761", "متزوج", 2, "علي بن أبي طالب", "طالب ماجستير محاسبة", "معلم حلقة", "592525761", "بنك/ ابراهيم محمد عزام", "10", ""),
            ("علي حسن عيد الرملاوي", "800327942", "1984-06-14", "598672476", "00972598672476", "متزوج", 3, "علي بن أبي طالب", "دبلوم", "معلم حلقة", "592206013", "علي حسن الرملاوي", "5", ""),
            ("محمد أمجد حمدي عزام", "407085190", "2001-02-16", "597018876", "00972597018876", "متزوج", 2, "علي بن أبي طالب", "بكالوريوس", "معلم حلقة", "597018876", "محمد أمجد عزام", "القران كاملاً", ""),
            ("وليد خالد عبد العزيز اسماعيل", "433288354", "2012-11-26", "592206875", "00972592206875", "أعزب", 6, "علي بن أبي طالب", "اعدادي", "معلم حلقة", "592206875", "خالد عبد العزيز اسماعيل", "القران كاملاً", ""),
            ("سامي محمد خليل نوفل", "424680361", "2007-05-08", "592201660", "00972592201660", "أعزب", 8, "علي بن أبي طالب", "طالب جامعي", "معلم حلقة", "599711715", "بنك/ محمد خليل نوفل", "القران كاملاً", ""),
            ("اسماعيل حسن  أحمد النبيه", "424549095", "2007-01-23", "566563711", "00972592563711", "أعزب", 7, "علي بن أبي طالب", "طالب جامعي", "معلم حلقة", "592479669", "علي حسن النبيه", "16", ""),
            ("خالد وائل خالد هنية", "409049343", "2003-07-27", "567124231", "00972567124231", "أعزب", 6, "علي بن أبي طالب", "بكالوريوس هندسة حاسوب", "معلم حلقة", "592485914", "خالد وائل هنية", "12", ""),
            ("أنور محمد أنور مرتجى", "429968845", "2010-03-10", "595279322", "00972598861561", "أعزب", 7, "علي بن أبي طالب", "طالب ثانوي", "معلم حلقة", "598861561", "محمد أنور مرتجى", "28", ""),
            ("براء رياض محمد علي الراعي", "427600481", "2009-02-17", "592490922", "00972592490922", "أعزب", 3, "علي بن أبي طالب", "طالب ثانوي", "معلم حلقة", "599531576", "بنك/ سماح فرج الراعي", "القران كاملاً", ""),
            ("يزن محمد خليل نوفل", "426466694", "2009-02-14", "599561798", "00972598437749", "أعزب", 8, "علي بن أبي طالب", "طالب ثانوي", "معلم حلقة", "599711715", "بنك/ محمد خليل نوفل", "القران كاملاً", ""),
            ("عبد الله شفيق عبد الرحمن الشيخ", "408433761", "2002-10-31", "592482526", "00972592482526", "أعزب", 5, "علي بن أبي طالب", "ثانوي", "معلم حلقة", "592482526", "بنك/ عبد الله شفيق الشيخ", "3", ""),
            ("رجب نبيل رجب اشتيوي", "432062453", "2012-07-05", "599059590", "00972599059590", "أعزب", 6, "علي بن أبي طالب", "إعدادي", "معلم حلقة", "599059590", "آية منصور شتيوي", "القرآن كاملاً", ""),
            ("أحمد خميس محمد سلمي", "801158650", "1988-08-01", "599192544", "00970599192544", "متزوج", 6, "علي بن أبي طالب", "دبلوم", "معلم دورات", "599192544", "احمد خميس سلمي", "14", ""),
            ("محمد وسيم خالد هنية", "429138365", "2009-07-17", "599780521", "00972599780521", "أعزب", 8, "علي بن أبي طالب", "ثانوي", "معلم حلقة", "", "", "5", ""),
            ("المعتصم بالله وائل خالد هنية", "431271303", "2011-03-10", "597898940", "00972597898940", "أعزب", 7, "علي بن أبي طالب", "إعدادي", "معلم حلقة", "592485914", "خالد وائل هنية", "القرآن كاملاً", ""),
            ("علي زياد محمد علي الراعي", "409519188", "2004-02-05", "592518708", "00972592518708", "أعزب", 8, "علي بن أبي طالب", "توجيهي", "معلم حلقة", "598692782", "سماح الراعي", "5", ""),
            ("انس محمد خليل نوفل", "424161982", "2006-06-19", "567034436", "00972567034436", "أعزب", 8, "علي بن أبي طالب", "طالب جامعي", "معلم حلقة", "567034436", "انس محمد نوفل", "10", ""),
            ("هيثم يحيى عطيه العزازي", "422660571", "2005-12-20", "593997824", "", "أعزب", null, "علي بن أبي طالب", "توجيهي", "معلم حلقة", "", "", "-", ""),
            ("عبد الرحمن وليد سليمان ابو لباد", "424577625", "2007-07-16", "592587954", "", "أعزب", null, "علي بن أبي طالب", "توجيهي", "معلم حلقة", "", "", "-", ""),
            ("احمد حازم خضر عياد", "424629350", "2007-06-28", "", "", "أعزب", 7, "علي بن أبي طالب", "توجيهي", "معلم حلقة", "", "", "-", ""),
            ("حمزة نعيم عطاالله عياد", "424641710", "2007-12-28", "594331714", "00972594331714", "أعزب", 8, "علي بن أبي طالب", "توجيهي", "معلم حلقة", "", "", "-", ""),
            ("زياد وائل سليم سلمي", "421401993", "2005-06-19", "594895497", "00970594895497", "أعزب", 8, "علي بن أبي طالب", "طالب جامعي", "معلم حلقة", "594895497", "زياد وائل سلمي", "-", ""),
            ("محمود فلاح سليمان بدوي", "403762180", "1998-03-30", "597235692", "00972597235692", "متزوج", 4, "علي بن أبي طالب", "توجيهي", "معلم حلقة", "597235692", "محمود فلاح بدوي", "-", ""),
            ("عبدالله وسيم  خالد هنية", "421055427", "2004-11-10", "567799345", "", "أعزب", 8, "علي بن أبي طالب", "توجيهي", "مساعد حلقة", "567799456", "بنك/ كاملة هنية", "-", "")
        };

        int imported = 0, updated = 0;
        foreach (var et in excelTeachers)
        {
            var idNumber = string.IsNullOrWhiteSpace(et.IdNum) ? null : et.IdNum.Trim();
            var teacher = await _db.Teachers.FirstOrDefaultAsync(t =>
                (!string.IsNullOrEmpty(idNumber) && t.IdentityNumber == idNumber) ||
                t.FullName == et.FullName);

            DateOnly dob = DateOnly.TryParse(et.Dob, out var parsedDob) ? parsedDob : new DateOnly(1995, 1, 1);

            if (teacher == null)
            {
                teacher = new Teacher
                {
                    FullName = et.FullName,
                    IdentityNumber = idNumber,
                    DateOfBirth = dob,
                    Contact = et.Mobile,
                    WhatsappNumber = et.Whatsapp,
                    SocialStatus = et.SocialStatus,
                    FamilyMembersCount = et.FamilyCount,
                    MosqueName = et.Mosque,
                    Qualification = et.Qualification,
                    TaskRole = et.TaskRole,
                    WalletNumber = et.WalletNum,
                    WalletOwner = et.WalletOwner,
                    MemorizedAjzaa = et.Memorized,
                    StudentsCountTarget = et.StudentsTarget,
                    RegistrationDate = new DateOnly(2026, 8, 29),
                    IsActive = true
                };
                _db.Teachers.Add(teacher);
                await _db.SaveChangesAsync();
                imported++;
            }
            else
            {
                if (!string.IsNullOrWhiteSpace(idNumber)) teacher.IdentityNumber = idNumber;
                if (!string.IsNullOrWhiteSpace(et.Mobile)) teacher.Contact = et.Mobile;
                if (!string.IsNullOrWhiteSpace(et.Whatsapp)) teacher.WhatsappNumber = et.Whatsapp;
                if (!string.IsNullOrWhiteSpace(et.SocialStatus)) teacher.SocialStatus = et.SocialStatus;
                if (et.FamilyCount.HasValue) teacher.FamilyMembersCount = et.FamilyCount;
                if (!string.IsNullOrWhiteSpace(et.Mosque)) teacher.MosqueName = et.Mosque;
                if (!string.IsNullOrWhiteSpace(et.Qualification)) teacher.Qualification = et.Qualification;
                if (!string.IsNullOrWhiteSpace(et.TaskRole)) teacher.TaskRole = et.TaskRole;
                if (!string.IsNullOrWhiteSpace(et.WalletNum)) teacher.WalletNumber = et.WalletNum;
                if (!string.IsNullOrWhiteSpace(et.WalletOwner)) teacher.WalletOwner = et.WalletOwner;
                if (!string.IsNullOrWhiteSpace(et.Memorized)) teacher.MemorizedAjzaa = et.Memorized;
                if (!string.IsNullOrWhiteSpace(et.StudentsTarget)) teacher.StudentsCountTarget = et.StudentsTarget;
                await _db.SaveChangesAsync();
                updated++;
            }

            var username = !string.IsNullOrWhiteSpace(idNumber) ? idNumber : (!string.IsNullOrWhiteSpace(et.Mobile) ? et.Mobile : $"tch_{teacher.Id}");
            var existingUser = await _db.Users.FirstOrDefaultAsync(u => u.TeacherId == teacher.Id || u.Username == username);
            if (existingUser == null)
            {
                _db.Users.Add(new User
                {
                    Username = username,
                    PasswordHash = _hasher.HashPassword("123456"),
                    PlainPassword = "123456",
                    Role = UserRole.Teacher,
                    FullName = teacher.FullName,
                    TeacherId = teacher.Id,
                    IsActive = true
                });
                await _db.SaveChangesAsync();
            }
            else
            {
                existingUser.Username = username;
                existingUser.FullName = teacher.FullName;
                existingUser.TeacherId = teacher.Id;
                existingUser.Role = UserRole.Teacher;
                existingUser.IsActive = true;
                if (string.IsNullOrEmpty(existingUser.PasswordHash) || existingUser.PlainPassword == "123456")
                {
                    existingUser.PasswordHash = _hasher.HashPassword("123456");
                    existingUser.PlainPassword = "123456";
                }
                await _db.SaveChangesAsync();
            }

            if (et.TaskRole.Contains("حلقة") && !await _db.Circles.AnyAsync(c => c.TeacherId == teacher.Id))
            {
                _db.Circles.Add(new Circle
                {
                    Name = $"حلقة {teacher.FullName}",
                    Timing = SessionTiming.Aser,
                    TeacherId = teacher.Id
                });
                await _db.SaveChangesAsync();
            }
        }

        return (imported, updated, null);
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

        var username = string.IsNullOrWhiteSpace(dto.Username) 
            ? "tch_" + Random.Shared.Next(10000, 99999) 
            : dto.Username.Trim();

        var password = string.IsNullOrWhiteSpace(dto.Password) 
            ? "123456" 
            : dto.Password.Trim();

        var userExists = await _db.Users.AnyAsync(u => u.Username.ToLower() == username.ToLower());
        if (userExists) username = "tch_" + Random.Shared.Next(100000, 999999);

        var t = new Teacher
        {
            FullName = dto.FullName.Trim(),
            Address = dto.Address?.Trim() ?? "",
            DateOfBirth = dto.DateOfBirth ?? DateOnly.FromDateTime(DateTime.Today),
            Contact = dto.Contact?.Trim() ?? "",
            RegistrationDate = DateOnly.FromDateTime(DateTime.Today),
            IsActive = true,
            IdentityNumber = dto.IdentityNumber?.Trim(),
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

        var user = new User
        {
            Username = username,
            PasswordHash = _hasher.HashPassword(password),
            PlainPassword = password,
            Role = UserRole.Teacher,
            FullName = t.FullName,
            TeacherId = t.Id,
            IsActive = true
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

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
        if (u != null) u.FullName = t.FullName;

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

        var circles = await _db.Circles.Where(c => c.TeacherId == id).ToListAsync();
        foreach (var c in circles)
        {
            c.TeacherId = null;
        }

        var user = await _db.Users.FirstOrDefaultAsync(u => u.TeacherId == id);
        if (user != null)
        {
            _db.Users.Remove(user);
        }

        _db.Teachers.Remove(t);
        await _db.SaveChangesAsync();
        return (true, teacherName, null);
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

    private static TeacherDto Map(Teacher t) => new(
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
        t.StudentsCountTarget
    );
}
