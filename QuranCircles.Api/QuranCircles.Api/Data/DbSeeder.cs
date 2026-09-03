using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Data;

public static partial class DbSeeder
{
    public static void Seed(AppDbContext db, PasswordHasher hasher)
    {
        // 1. إضافة المستخدمين الإداريين الأساسيين فقط عند تشغيل النظام لأول مرة على قاعدة بيانات فارغة
        if (!db.Users.Any())
        {
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

        // 2. استيراد بيانات الطلاب الأساسية لمرة واحدة فقط إذا كان جدول الطلاب فارغاً
        SeedStudents(db, hasher);
    }

    public static void MigrateSchema(AppDbContext db)
    {
        if (!db.Database.IsSqlite()) return;

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

            // Ensure Circles table has AssistantTeacherId column
            try
            {
                db.Database.ExecuteSqlRaw("ALTER TABLE Circles ADD COLUMN AssistantTeacherId INTEGER;");
            }
            catch { /* Column already exists */ }

            // 1.8 Ensure FinancialTransactions table exists
            try
            {
                db.Database.ExecuteSqlRaw(@"
                    CREATE TABLE IF NOT EXISTS FinancialTransactions (
                        Id INTEGER PRIMARY KEY AUTOINCREMENT,
                        Type INTEGER NOT NULL,
                        Amount REAL NOT NULL,
                        Currency TEXT DEFAULT 'ILS',
                        Title TEXT NOT NULL,
                        Category TEXT,
                        DonorName TEXT,
                        DonorSource TEXT,
                        RecipientName TEXT,
                        PaymentMethod INTEGER NOT NULL,
                        PaymentDetails TEXT,
                        TransactionDate TEXT NOT NULL,
                        ReferenceNumber TEXT,
                        Notes TEXT,
                        CreatedByUserId INTEGER,
                        CreatedByName TEXT,
                        CreatedAt TEXT NOT NULL
                    );
                ");
            }
            catch { }

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

            // 5. Seed initial teachers ONLY if database is brand new and completely empty
            try
            {
                if (!db.Teachers.Any())
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

                    var teacherHasher = new PasswordHasher();

                    foreach (var et in excelTeachers)
                    {
                        var idNumber = string.IsNullOrWhiteSpace(et.IdNum) ? null : et.IdNum.Trim();
                        DateOnly dob = DateOnly.TryParse(et.Dob, out var parsedDob) ? parsedDob : new DateOnly(1995, 1, 1);

                        var teacher = new Teacher
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
                        db.Teachers.Add(teacher);
                        db.SaveChanges();

                        var assignedRole = (et.FullName.Contains("علي حسن") && et.FullName.Contains("النبيه")) || (et.TaskRole != null && et.TaskRole.Contains("مركز البيان")) || idNumber == "408118297"
                            ? UserRole.Admin
                            : UserRole.Teacher;

                        var username = !string.IsNullOrWhiteSpace(idNumber) ? idNumber : (!string.IsNullOrWhiteSpace(et.Mobile) ? et.Mobile : $"tch_{teacher.Id}");
                        db.Users.Add(new User
                        {
                            Username = username,
                            PasswordHash = teacherHasher.HashPassword("123456"),
                            PlainPassword = "123456",
                            Role = assignedRole,
                            FullName = teacher.FullName,
                            TeacherId = teacher.Id,
                            IsActive = true
                        });
                        db.SaveChanges();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Seeder Notice] Syncing teachers: {ex.Message}");
            }

            // 6. Force immediate SQLite WAL Checkpoint to flush all recent changes directly into the main quran.db file
            try
            {
                db.Database.ExecuteSqlRaw("PRAGMA wal_checkpoint(TRUNCATE);");
            }
            catch { }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Schema migration notice: {ex.Message}");
        }
    }
}
