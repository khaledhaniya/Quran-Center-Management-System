using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Data;

public static class DbSeeder
{
    public static void Seed(AppDbContext db, PasswordHasher hasher)
    {
        // إذا كان هناك مستخدمون في النظام، فهذا يعني أن البذر تم مسبقاً
        if (db.Users.Any()) return;

        var today = DateOnly.FromDateTime(DateTime.Today);

        // 1. إضافة المعلمين
        var t1 = new Teacher { FullName = "الشيخ أحمد", Address = "نابلس", Contact = "0599000001", DateOfBirth = new DateOnly(1985, 3, 10), RegistrationDate = today };
        var t2 = new Teacher { FullName = "الشيخ خالد", Address = "جنين", Contact = "0599000002", DateOfBirth = new DateOnly(1990, 7, 1), RegistrationDate = today };
        db.Teachers.AddRange(t1, t2);
        db.SaveChanges();

        // 2. إضافة الحلقات
        var c1 = new Circle { Name = "حلقة الفجر", Timing = SessionTiming.Fajr, TeacherId = t1.Id };
        var c2 = new Circle { Name = "حلقة المغرب", Timing = SessionTiming.Maghrib, TeacherId = t2.Id };
        db.Circles.AddRange(c1, c2);
        db.SaveChanges();

        // 3. إضافة الطلاب
        var s1 = new Student { FullName = "محمد علي", Address = "نابلس", FamilyContact = "0598000001", DateOfBirth = new DateOnly(2012, 1, 5), RegistrationDate = today, CircleId = c1.Id, ParentId = 100 };
        var s2 = new Student { FullName = "عبدالله سامي", Address = "نابلس", FamilyContact = "0598000002", DateOfBirth = new DateOnly(2011, 9, 20), RegistrationDate = today, CircleId = c1.Id, ParentId = 100 };
        var s3 = new Student { FullName = "يوسف ماهر", Address = "جنين", FamilyContact = "0598000003", DateOfBirth = new DateOnly(2013, 4, 12), RegistrationDate = today, CircleId = c2.Id, ParentId = 101 };
        db.Students.AddRange(s1, s2, s3);
        db.SaveChanges();

        // 4. إضافة حسابات المستخدمين وتشفير كلمات المرور الخاصة بهم مع حفظ كلمة المرور للمطور
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
            // حساب المعلم الشيخ أحمد
            new User 
            { 
                Username = "ahmad", 
                PasswordHash = hasher.HashPassword("123456"), 
                PlainPassword = "123456",
                Role = UserRole.Teacher, 
                FullName = "الشيخ أحمد", 
                TeacherId = t1.Id, 
                IsActive = true 
            },
            // حساب المعلم الشيخ خالد
            new User 
            { 
                Username = "khaled", 
                PasswordHash = hasher.HashPassword("123456"), 
                PlainPassword = "123456",
                Role = UserRole.Teacher, 
                FullName = "الشيخ خالد", 
                TeacherId = t2.Id, 
                IsActive = true 
            },
            // حساب الطالب محمد علي
            new User 
            { 
                Username = "mohammad", 
                PasswordHash = hasher.HashPassword("123456"), 
                PlainPassword = "123456",
                Role = UserRole.Student, 
                FullName = "محمد علي", 
                StudentId = s1.Id, 
                IsActive = true 
            },
            // حساب الطالب عبدالله سامي
            new User 
            { 
                Username = "abdullah", 
                PasswordHash = hasher.HashPassword("123456"), 
                PlainPassword = "123456",
                Role = UserRole.Student, 
                FullName = "عبدالله سامي", 
                StudentId = s2.Id, 
                IsActive = true 
            },
            // حساب الطالب يوسف ماهر
            new User 
            { 
                Username = "yousef", 
                PasswordHash = hasher.HashPassword("123456"), 
                PlainPassword = "123456",
                Role = UserRole.Student, 
                FullName = "يوسف ماهر", 
                StudentId = s3.Id, 
                IsActive = true 
            },
            // حساب ولي الأمر الأول (والد محمد وعبدالله) - يرسل ParentId = 100
            new User 
            { 
                Username = "parent100", 
                PasswordHash = hasher.HashPassword("123456"), 
                PlainPassword = "123456",
                Role = UserRole.Parent, 
                FullName = "أبو محمد (ولي أمر محمد وعبد الله)", 
                ParentId = 100, // يمثل ParentId المستهدف في الكنترولر
                IsActive = true 
            },
            // حساب ولي الأمر الثاني (والد يوسف) - يرسل ParentId = 101
            new User 
            { 
                Username = "parent101", 
                PasswordHash = hasher.HashPassword("123456"), 
                PlainPassword = "123456",
                Role = UserRole.Parent, 
                FullName = "أبو يوسف (ولي أمر يوسف)", 
                ParentId = 101, // يمثل ParentId المستهدف في الكنترولر
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

        // 5. إضافة تعاميم تجريبية افتراضية
        db.Announcements.AddRange(
            new Announcement
            {
                Title = "ترحيب حار بجميع الحضور",
                Content = "أهلاً وسهلاً بجميع الإخوة والمعلمين والطلاب وأولياء الأمور في منصة حلقات مركز القرآن الكريم. نسأل الله أن يتقبل منا ومنكم صالح الأعمال.",
                DateTimeSent = DateTime.UtcNow.AddDays(-2),
                TargetType = AnnouncementTarget.All,
                SenderName = "مدير المركز"
            },
            new Announcement
            {
                Title = "اجتماع خاص لجميع المعلمين",
                Content = "يرجى من جميع المعلمين الحضور إلى قاعة الاجتماعات يوم السبت المقبل لمناقشة خطة الحفظ والمتابعة الجديدة.",
                DateTimeSent = DateTime.UtcNow.AddDays(-1),
                TargetType = AnnouncementTarget.Teacher,
                TargetId = t1.Id, // الشيخ أحمد كمثال
                SenderName = "مدير المركز"
            },
            new Announcement
            {
                Title = "تنبيه هام لحلقة الفجر",
                Content = "يرجى الالتزام بالوقت المحدد للحلقة والتأكد من تحضير الأجزاء المطلوبة للتسميع مسبقاً.",
                DateTimeSent = DateTime.UtcNow.AddHours(-5),
                TargetType = AnnouncementTarget.Circle,
                TargetId = c1.Id, // حلقة الفجر
                SenderName = "الشيخ أحمد"
            },
            new Announcement
            {
                Title = "رسالة تهنئة بالتميز للطالب محمد علي",
                Content = "نبارك للطالب المتميز محمد علي لحصوله على درجة ممتاز في تسميع سورة البقرة بالكامل. استمر في هذا الأداء الرائع!",
                DateTimeSent = DateTime.UtcNow.AddHours(-1),
                TargetType = AnnouncementTarget.Student,
                TargetId = s1.Id, // محمد علي
                SenderName = "الشيخ أحمد"
            }
        );
        db.SaveChanges();

        // 6. إضافة جلسات تسميع للتغذية الراءعة وخريطة الحرارة (Mental Quran Heatmap)
        db.Sessions.AddRange(
            new RecitationSession { StudentId = s1.Id, SessionDate = today.AddDays(-10), SurahName = "الفاتحة", FromVerse = 1, ToVerse = 7, Assessment = AssessmentLevel.Excellent, Notes = "قراءة ممتازة ومجودة" },
            new RecitationSession { StudentId = s1.Id, SessionDate = today.AddDays(-9), SurahName = "البقرة", FromVerse = 1, ToVerse = 25, Assessment = AssessmentLevel.Excellent, Notes = "حفظ متين" },
            new RecitationSession { StudentId = s1.Id, SessionDate = today.AddDays(-8), SurahName = "البقرة", FromVerse = 26, ToVerse = 50, Assessment = AssessmentLevel.VeryGood },
            new RecitationSession { StudentId = s1.Id, SessionDate = today.AddDays(-7), SurahName = "البقرة", FromVerse = 51, ToVerse = 100, Assessment = AssessmentLevel.Medium, Notes = "يحتاج مراجعة الآيات الأخيرة" },
            new RecitationSession { StudentId = s1.Id, SessionDate = today.AddDays(-6), SurahName = "النساء", FromVerse = 1, ToVerse = 30, Assessment = AssessmentLevel.Rejected, Notes = "لم يحضر جيداً" },
            new RecitationSession { StudentId = s2.Id, SessionDate = today.AddDays(-5), SurahName = "البقرة", FromVerse = 1, ToVerse = 15, Assessment = AssessmentLevel.Excellent },
            new RecitationSession { StudentId = s3.Id, SessionDate = today.AddDays(-4), SurahName = "الكهف", FromVerse = 1, ToVerse = 10, Assessment = AssessmentLevel.VeryGood }
        );
        db.SaveChanges();

        // 7. إضافة دورات تعليمية (Courses)
        var course1 = new Course { Name = "دورة أحكام التجويد المبتدئة", Description = "تغطي مخارج الحروف وصفاتها والمدود الأساسية", TeacherId = t1.Id, IsActive = true };
        var course2 = new Course { Name = "دورة التجويد المتقدم والتلاوة", Description = "تغطي أحكام الوقف والابتداء والاتقان العملي", TeacherId = t2.Id, IsActive = true };
        db.Courses.AddRange(course1, course2);
        db.SaveChanges();

        // 8. تسجيل الطلاب بالدورات (Course Enrollments)
        var en1 = new CourseEnrollment { CourseId = course1.Id, StudentId = s1.Id, Grade = 88, Status = "Passed", CertificateCode = "CERT-8812-AQ", CertificateDate = today.AddDays(-1) };
        var en2 = new CourseEnrollment { CourseId = course1.Id, StudentId = s2.Id, Grade = null, Status = "Enrolled" };
        var en3 = new CourseEnrollment { CourseId = course2.Id, StudentId = s3.Id, Grade = null, Status = "Enrolled" };
        db.CourseEnrollments.AddRange(en1, en2, en3);
        db.SaveChanges();

        // 9. إضافة تسميع الأحاديث (Hadith Sessions)
        db.HadithSessions.AddRange(
            new HadithSession { StudentId = s1.Id, HadithBook = "الأربعين النووية", HadithNumber = 1, SessionDate = today.AddDays(-4), Points = 10, Notes = "عن أمير المؤمنين عمر بن الخطاب" },
            new HadithSession { StudentId = s1.Id, HadithBook = "الأربعين النووية", HadithNumber = 2, SessionDate = today.AddDays(-3), Points = 10, Notes = "حديث جبريل طويل" },
            new HadithSession { StudentId = s1.Id, HadithBook = "الأربعين النووية", HadithNumber = 3, SessionDate = today.AddDays(-2), Points = 10 },
            new HadithSession { StudentId = s2.Id, HadithBook = "الأربعين النووية", HadithNumber = 1, SessionDate = today.AddDays(-2), Points = 10 }
        );
        db.SaveChanges();

        // 10. إضافة ترشيحات الاختبارات (Exam Nominations)
        var nom1 = new ExamNomination { StudentId = s2.Id, TeacherId = t1.Id, NominationType = "Quran", JuzStart = 1, JuzEnd = 5, Status = "Pending", NominationDate = today.AddDays(-2) };
        var nom2 = new ExamNomination { StudentId = s1.Id, TeacherId = t1.Id, NominationType = "Quran", JuzStart = 1, JuzEnd = 10, Status = "Completed", NominationDate = today.AddDays(-5), ExamDate = DateTime.Now.AddDays(-1) };
        db.ExamNominations.AddRange(nom1, nom2);
        db.SaveChanges();

        // 11. إضافة نتائج الاختبارات (Exam Results)
        var res2 = new ExamResult { ExamNominationId = nom2.Id, ExaminerId = 2, MajorMistakes = 1, MinorMistakes = 3, Grade = 92.5, Notes = "حفظ مميز مع لحن جلي واحد في الوقف ولحون خفية في الإدغام", ExamDate = DateTime.Now.AddDays(-1) };
        db.ExamResults.Add(res2);
        db.SaveChanges();

        // 12. إضافة سجل الرقابة (Audit Logs)
        db.AuditLogs.AddRange(
            new AuditLog { Username = "ahmad", Action = "NominateStudent", Details = $"ترشيح الطالب {s2.FullName} لاختبار الأجزاء 1-5", Timestamp = DateTime.UtcNow.AddDays(-2), IpAddress = "::1" },
            new AuditLog { Username = "admin", Action = "EvaluateExam", Details = $"تقييم اختبار الطالب {s1.FullName} لـ الأجزاء 1-10 بالدرجة 92.5", Timestamp = DateTime.UtcNow.AddDays(-1), IpAddress = "127.0.0.1" },
            new AuditLog { Username = "dev", Action = "ViewCredentials", Details = "استعلام عن كلمات مرور المعلمين والمدير", Timestamp = DateTime.UtcNow.AddHours(-2), IpAddress = "::1" }
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

            // 5. Seed / Sync all 35 Teachers from 29-8 Center Database
            try
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
                    var teacher = db.Teachers.FirstOrDefault(t => 
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
                        db.Teachers.Add(teacher);
                        db.SaveChanges();
                    }
                    else
                    {
                        // Non-destructive update of existing teacher metadata
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
                        db.SaveChanges();
                    }

                    // Create or update User account: Username = Identity Number, Password = 123456
                    var username = !string.IsNullOrWhiteSpace(idNumber) ? idNumber : (!string.IsNullOrWhiteSpace(et.Mobile) ? et.Mobile : $"tch_{teacher.Id}");
                    var existingUser = db.Users.FirstOrDefault(u => u.TeacherId == teacher.Id || u.Username == username);
                    if (existingUser == null)
                    {
                        db.Users.Add(new User
                        {
                            Username = username,
                            PasswordHash = teacherHasher.HashPassword("123456"),
                            PlainPassword = "123456",
                            Role = UserRole.Teacher,
                            FullName = teacher.FullName,
                            TeacherId = teacher.Id,
                            IsActive = true
                        });
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
                            existingUser.PasswordHash = teacherHasher.HashPassword("123456");
                            existingUser.PlainPassword = "123456";
                        }
                    }
                    db.SaveChanges();

                    // If teacher has a circle role and no circle exists, create their circle
                    if (et.TaskRole.Contains("حلقة") && !db.Circles.Any(c => c.TeacherId == teacher.Id))
                    {
                        db.Circles.Add(new Circle
                        {
                            Name = $"حلقة {teacher.FullName}",
                            Timing = SessionTiming.Aser,
                            TeacherId = teacher.Id
                        });
                        db.SaveChanges();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Seeder Error] Error seeding teachers: {ex.Message}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Schema migration notice: {ex.Message}");
        }
    }
}

