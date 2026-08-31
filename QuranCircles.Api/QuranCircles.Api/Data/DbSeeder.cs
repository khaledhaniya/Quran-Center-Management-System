using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Data;

public static class DbSeeder
{
    public static void Seed(AppDbContext db, PasswordHasher hasher)
    {
        // إذا كان هناك أي مستخدم مسجل في النظام، لا تقم بإضافة أي بيانات تجريبية
        if (db.Users.Any()) return;

        // إضافة المستخدمين الإداريين الأساسيين فقط عند تشغيل النظام لأول مرة على قاعدة بيانات فارغة تماماً
        db.Users.AddRange(
            // المطور (Developer)
            new User 
            { 
                Username = "dev", 
                PasswordHash = hasher.HashPassword("dev123"), 
                PlainPassword = "dev123",
                Role = UserRole.Developer, 
                FullName = "مطور النظام", 
                IsActive = true 
            },
            // مدير المركز (Admin)
            new User 
            { 
                Username = "admin", 
                PasswordHash = hasher.HashPassword("admin123"), 
                PlainPassword = "admin123",
                Role = UserRole.Admin, 
                FullName = "مدير المركز", 
                IsActive = true 
            },
            // حساب مشرف ومقيم الاختبارات
            new User
            {
                Username = "wael",
                PasswordHash = hasher.HashPassword("wael123"),
                PlainPassword = "wael123",
                Role = UserRole.ExamSupervisor,
                FullName = "المشرف وائل هلية",
                IsActive = true
            }
        );
        db.SaveChanges();
    }

    public static void MigrateSchema(AppDbContext db)
    {
        try
        {
            // 1. Add missing columns to Students table safely
            var studentColumns = new[]
            {
                ("TargetAjzaaCount", "INTEGER NOT NULL DEFAULT 30"),
                ("PlanType", "TEXT"),
                ("PlanStartDate", "TEXT"),
                ("PlanTargetDate", "TEXT"),
                ("DailyPacePages", "REAL NOT NULL DEFAULT 1.0"),
                ("CompletedAjzaa", "TEXT"),
                ("StudentIdentityNumber", "TEXT"),
                ("PreviousQuranMemorization", "TEXT"),
                ("StudentMobile", "TEXT"),
                ("StudentWhatsapp", "TEXT"),
                ("HealthStatus", "TEXT"),
                ("FatherStatus", "TEXT"),
                ("MotherStatus", "TEXT"),
                ("Kinship", "TEXT"),
                ("ParentIdentityNumber", "TEXT"),
                ("WhatsappNumber", "TEXT"),
                ("WalletNumber", "TEXT"),
                ("BankAccountNumber", "TEXT"),
                ("BankName", "TEXT"),
                ("OriginalAddress", "TEXT"),
                ("OriginalHousingType", "TEXT"),
                ("OriginalHousingStatus", "TEXT"),
                ("CurrentAddress", "TEXT"),
                ("CurrentHousingType", "TEXT"),
                ("Notes", "TEXT")
            };

            var existingCols = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            try
            {
                var conn = db.Database.GetDbConnection();
                if (conn.State != System.Data.ConnectionState.Open)
                    conn.Open();

                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = "PRAGMA table_info(Students);";
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            existingCols.Add(reader.GetString(1));
                        }
                    }
                }
            }
            catch { }

            foreach (var (colName, colType) in studentColumns)
            {
                if (!existingCols.Contains(colName))
                {
                    try
                    {
                        db.Database.ExecuteSqlRaw($"ALTER TABLE Students ADD COLUMN {colName} {colType};");
                    }
                    catch { /* Column already exists */ }
                }
            }

            // 1.5 Ensure Teachers table has all 29-8 Center Database Columns
            var teacherColumns = new (string Name, string Type)[]
            {
                ("IdentityNumber", "TEXT"),
                ("WhatsappNumber", "TEXT"),
                ("SocialStatus", "TEXT"),
                ("FamilyMembersCount", "INTEGER"),
                ("MosqueName", "TEXT"),
                ("Qualification", "TEXT"),
                ("TaskRole", "TEXT"),
                ("WalletNumber", "TEXT"),
                ("WalletOwner", "TEXT"),
                ("MemorizedAjzaa", "TEXT"),
                ("StudentsCountTarget", "TEXT")
            };

            var existingTeacherCols = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            try
            {
                var conn = db.Database.GetDbConnection();
                if (conn.State != System.Data.ConnectionState.Open)
                    conn.Open();

                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = "PRAGMA table_info(Teachers);";
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            existingTeacherCols.Add(reader.GetString(1));
                        }
                    }
                }
            }
            catch { }

            foreach (var (colName, colType) in teacherColumns)
            {
                if (!existingTeacherCols.Contains(colName))
                {
                    try
                    {
                        db.Database.ExecuteSqlRaw($"ALTER TABLE Teachers ADD COLUMN {colName} {colType};");
                    }
                    catch { /* Column already exists */ }
                }
            }

            // 2. Ensure SystemSettings table exists and has all new columns
            try
            {
                db.Database.ExecuteSqlRaw(@"
                    CREATE TABLE IF NOT EXISTS SystemSettings (
                        Id INTEGER PRIMARY KEY AUTOINCREMENT,
                        CenterName TEXT,
                        MosqueName TEXT,
                        CenterAddress TEXT,
                        SupportPhone TEXT,
                        SupportEmail TEXT,
                        WelcomeMessage TEXT,
                        LogoUrl TEXT,
                        ThemeStyle TEXT,
                        PassingScoreThreshold INTEGER NOT NULL DEFAULT 70,
                        MinAttendancePercentForExam INTEGER NOT NULL DEFAULT 75,
                        MaxStudentsPerCircle INTEGER NOT NULL DEFAULT 20,
                        MaxAbsenceDaysWarning INTEGER NOT NULL DEFAULT 3,
                        AllowTeacherEditStudentPlan INTEGER NOT NULL DEFAULT 1,
                        AllowTeacherSelfEnrollment INTEGER NOT NULL DEFAULT 1,
                        HideParentPhoneFromTeacher INTEGER NOT NULL DEFAULT 0,
                        AllowStudentProfileEditRequests INTEGER NOT NULL DEFAULT 1,
                        EnforceDailyAttendanceRecording INTEGER NOT NULL DEFAULT 1,
                        ShowStudentCountToTeacher INTEGER NOT NULL DEFAULT 1,
                        ShowCumulativeAttendance INTEGER NOT NULL DEFAULT 1,
                        EnableCertificates INTEGER NOT NULL DEFAULT 1,
                        SignatoryName TEXT,
                        SignatoryTitle TEXT,
                        ShowHonorsBoard INTEGER NOT NULL DEFAULT 1,
                        AllowPublicAnnouncements INTEGER NOT NULL DEFAULT 1,
                        EnableAbsenceAutoAlert INTEGER NOT NULL DEFAULT 1,
                        AbsenceAlertTemplate TEXT,
                        MaintenanceMode INTEGER NOT NULL DEFAULT 0,
                        UpdatedAt TEXT NOT NULL
                    );
                ");

                var existingSettingsCols = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                using (var cmd = db.Database.GetDbConnection().CreateCommand())
                {
                    cmd.CommandText = "PRAGMA table_info(SystemSettings);";
                    var conn = cmd.Connection;
                    if (conn != null && conn.State != System.Data.ConnectionState.Open) conn.Open();
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            existingSettingsCols.Add(reader["name"]?.ToString() ?? "");
                        }
                    }
                }

                var settingsColumns = new Dictionary<string, string>
                {
                    { "CenterName", "TEXT" },
                    { "MosqueName", "TEXT" },
                    { "CenterAddress", "TEXT" },
                    { "SupportPhone", "TEXT" },
                    { "SupportEmail", "TEXT" },
                    { "WelcomeMessage", "TEXT" },
                    { "LogoUrl", "TEXT" },
                    { "ThemeStyle", "TEXT" },
                    { "PassingScoreThreshold", "INTEGER NOT NULL DEFAULT 70" },
                    { "MinAttendancePercentForExam", "INTEGER NOT NULL DEFAULT 75" },
                    { "MaxStudentsPerCircle", "INTEGER NOT NULL DEFAULT 20" },
                    { "MaxAbsenceDaysWarning", "INTEGER NOT NULL DEFAULT 3" },
                    { "AllowTeacherEditStudentPlan", "INTEGER NOT NULL DEFAULT 1" },
                    { "AllowTeacherSelfEnrollment", "INTEGER NOT NULL DEFAULT 1" },
                    { "HideParentPhoneFromTeacher", "INTEGER NOT NULL DEFAULT 0" },
                    { "AllowStudentProfileEditRequests", "INTEGER NOT NULL DEFAULT 1" },
                    { "EnforceDailyAttendanceRecording", "INTEGER NOT NULL DEFAULT 1" },
                    { "ShowStudentCountToTeacher", "INTEGER NOT NULL DEFAULT 1" },
                    { "ShowCumulativeAttendance", "INTEGER NOT NULL DEFAULT 1" },
                    { "EnableCertificates", "INTEGER NOT NULL DEFAULT 1" },
                    { "SignatoryName", "TEXT" },
                    { "SignatoryTitle", "TEXT" },
                    { "ShowHonorsBoard", "INTEGER NOT NULL DEFAULT 1" },
                    { "AllowPublicAnnouncements", "INTEGER NOT NULL DEFAULT 1" },
                    { "EnableAbsenceAutoAlert", "INTEGER NOT NULL DEFAULT 1" },
                    { "AbsenceAlertTemplate", "TEXT" },
                    { "MaintenanceMode", "INTEGER NOT NULL DEFAULT 0" },
                    { "UpdatedAt", "TEXT NOT NULL DEFAULT '2026-01-01T00:00:00Z'" }
                };

                foreach (var (colName, colType) in settingsColumns)
                {
                    if (!existingSettingsCols.Contains(colName))
                    {
                        try
                        {
                            db.Database.ExecuteSqlRaw($"ALTER TABLE SystemSettings ADD COLUMN {colName} {colType};");
                        }
                        catch { }
                    }
                }
            }
            catch { }

            // 3. Ensure default SystemSettings row exists and is healthy
            try
            {
                var existingSettings = db.SystemSettings.FirstOrDefault();
                if (existingSettings == null)
                {
                    db.SystemSettings.Add(new SystemSettings
                    {
                        CenterName = "مركز البيان لتعليم القرآن الكريم وتدريس علومه",
                        MosqueName = "مسجد علي بن أبي طالب",
                        CenterAddress = "فلسطين - غزة - المقر الرئيسي",
                        SupportPhone = "+970599000000",
                        SupportEmail = "info@albayan.quran",
                        WelcomeMessage = "أهلاً وسهلاً بكم في منصة مركز البيان لتعليم القرآن الكريم والعلوم الشرعية",
                        ThemeStyle = "Classic",
                        PassingScoreThreshold = 70,
                        MinAttendancePercentForExam = 75,
                        MaxStudentsPerCircle = 20,
                        MaxAbsenceDaysWarning = 3,
                        AllowTeacherEditStudentPlan = true,
                        AllowTeacherSelfEnrollment = true,
                        HideParentPhoneFromTeacher = false,
                        AllowStudentProfileEditRequests = true,
                        EnforceDailyAttendanceRecording = true,
                        ShowStudentCountToTeacher = true,
                        ShowCumulativeAttendance = true,
                        EnableCertificates = true,
                        SignatoryName = "فضيلة الشيخ / رئيس المركز",
                        SignatoryTitle = "المشرف العام على حلقات تحفيظ القرآن الكريم",
                        ShowHonorsBoard = true,
                        AllowPublicAnnouncements = true,
                        EnableAbsenceAutoAlert = true,
                        AbsenceAlertTemplate = "نود إشعاركم بغياب الطالب/ة اليوم عن حلقة القرآن الكريم، نرجو المتابعة مع إدارة المركز.",
                        MaintenanceMode = false,
                        UpdatedAt = DateTime.UtcNow
                    });
                    db.SaveChanges();
                }
                else
                {
                    // Automatic self-healing: if any Arabic field got corrupted with question marks, restore clean Arabic
                    bool repaired = false;
                    if (string.IsNullOrWhiteSpace(existingSettings.CenterName) || existingSettings.CenterName.Contains("?"))
                    {
                        existingSettings.CenterName = "مركز البيان لتعليم القرآن الكريم وتدريس علومه";
                        repaired = true;
                    }
                    if (string.IsNullOrWhiteSpace(existingSettings.MosqueName) || existingSettings.MosqueName.Contains("?"))
                    {
                        existingSettings.MosqueName = "مسجد علي بن أبي طالب";
                        repaired = true;
                    }
                    if (string.IsNullOrWhiteSpace(existingSettings.WelcomeMessage) || existingSettings.WelcomeMessage.Contains("?"))
                    {
                        existingSettings.WelcomeMessage = "أهلاً وسهلاً بكم في منصة مركز البيان لتعليم القرآن الكريم والعلوم الشرعية";
                        repaired = true;
                    }
                    if (string.IsNullOrWhiteSpace(existingSettings.SignatoryName) || existingSettings.SignatoryName.Contains("?"))
                    {
                        existingSettings.SignatoryName = "فضيلة الشيخ / رئيس المركز";
                        repaired = true;
                    }
                    if (string.IsNullOrWhiteSpace(existingSettings.SignatoryTitle) || existingSettings.SignatoryTitle.Contains("?"))
                    {
                        existingSettings.SignatoryTitle = "المشرف العام على حلقات تحفيظ القرآن الكريم";
                        repaired = true;
                    }
                    if (repaired)
                    {
                        existingSettings.UpdatedAt = DateTime.UtcNow;
                        db.SaveChanges();
                    }
                }
            }
            catch { }

            // 4. Ensure existing users have a valid password hash without resetting their passwords
            try
            {
                var users = db.Users.ToList();
                var hasher = new PasswordHasher();
                bool changed = false;

                foreach (var u in users)
                {
                    if (string.IsNullOrEmpty(u.PasswordHash) && !string.IsNullOrEmpty(u.PlainPassword))
                    {
                        u.PasswordHash = hasher.HashPassword(u.PlainPassword);
                        changed = true;
                    }
                }

                if (changed)
                {
                    db.SaveChanges();
                }
            }
            catch { }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Schema migration notice: {ex.Message}");
        }
    }
}
