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
                PasswordHash = hasher.HashPassword("teacher123"), 
                PlainPassword = "teacher123",
                Role = UserRole.Teacher, 
                FullName = "الشيخ أحمد", 
                TeacherId = t1.Id, 
                IsActive = true 
            },
            // حساب المعلم الشيخ خالد
            new User 
            { 
                Username = "khaled", 
                PasswordHash = hasher.HashPassword("teacher123"), 
                PlainPassword = "teacher123",
                Role = UserRole.Teacher, 
                FullName = "الشيخ خالد", 
                TeacherId = t2.Id, 
                IsActive = true 
            },
            // حساب الطالب محمد علي
            new User 
            { 
                Username = "mohammad", 
                PasswordHash = hasher.HashPassword("student123"), 
                PlainPassword = "student123",
                Role = UserRole.Student, 
                FullName = "محمد علي", 
                StudentId = s1.Id, 
                IsActive = true 
            },
            // حساب الطالب عبدالله سامي
            new User 
            { 
                Username = "abdullah", 
                PasswordHash = hasher.HashPassword("student123"), 
                PlainPassword = "student123",
                Role = UserRole.Student, 
                FullName = "عبدالله سامي", 
                StudentId = s2.Id, 
                IsActive = true 
            },
            // حساب الطالب يوسف ماهر
            new User 
            { 
                Username = "yousef", 
                PasswordHash = hasher.HashPassword("student123"), 
                PlainPassword = "student123",
                Role = UserRole.Student, 
                FullName = "يوسف ماهر", 
                StudentId = s3.Id, 
                IsActive = true 
            },
            // حساب ولي الأمر الأول (والد محمد وعبدالله) - يرسل ParentId = 100
            new User 
            { 
                Username = "parent100", 
                PasswordHash = hasher.HashPassword("parent123"), 
                PlainPassword = "parent123",
                Role = UserRole.Parent, 
                FullName = "أبو محمد (ولي أمر محمد وعبد الله)", 
                ParentId = 100, // يمثل ParentId المستهدف في الكنترولر
                IsActive = true 
            },
            // حساب ولي الأمر الثاني (والد يوسف) - يرسل ParentId = 101
            new User 
            { 
                Username = "parent101", 
                PasswordHash = hasher.HashPassword("parent123"), 
                PlainPassword = "parent123",
                Role = UserRole.Parent, 
                FullName = "أبو يوسف (ولي أمر يوسف)", 
                ParentId = 101, // يمثل ParentId المستهدف في الكنترولر
                IsActive = true 
            },
            // حساب مشرف ومقيم الاختبارات
            new User
            {
                Username = "wael",
                PasswordHash = hasher.HashPassword("exam123"),
                PlainPassword = "exam123",
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

            foreach (var (colName, colType) in studentColumns)
            {
                try
                {
                    db.Database.ExecuteSqlRaw($"ALTER TABLE Students ADD COLUMN {colName} {colType};");
                }
                catch { /* Column already exists */ }
            }

            // 2. Ensure SystemSettings table exists
            try
            {
                db.Database.ExecuteSqlRaw(@"
                    CREATE TABLE IF NOT EXISTS SystemSettings (
                        Id INTEGER PRIMARY KEY AUTOINCREMENT,
                        CenterName TEXT,
                        MosqueName TEXT,
                        SupportPhone TEXT,
                        WelcomeMessage TEXT,
                        ThemeStyle TEXT,
                        ShowStudentCountToTeacher INTEGER NOT NULL DEFAULT 1,
                        ShowCumulativeAttendance INTEGER NOT NULL DEFAULT 1,
                        AllowTeacherSelfEnrollment INTEGER NOT NULL DEFAULT 1,
                        AllowPublicAnnouncements INTEGER NOT NULL DEFAULT 1,
                        EnableCertificates INTEGER NOT NULL DEFAULT 1,
                        UpdatedAt TEXT NOT NULL
                    );
                ");
            }
            catch { }

            // 3. Ensure default SystemSettings row exists
            try
            {
                if (!db.SystemSettings.Any())
                {
                    db.SystemSettings.Add(new SystemSettings
                    {
                        CenterName = "مركز البيان لتعليم القرآن الكريم",
                        MosqueName = "مسجد علي بن أبي طالب",
                        SupportPhone = "+970599000000",
                        WelcomeMessage = "مرحباً بكم في منصة تحفيظ القرآن الكريم والعلوم الشرعية",
                        ThemeStyle = "Classic",
                        ShowStudentCountToTeacher = true,
                        ShowCumulativeAttendance = true,
                        AllowTeacherSelfEnrollment = true,
                        AllowPublicAnnouncements = true,
                        EnableCertificates = true,
                        UpdatedAt = DateTime.UtcNow
                    });
                    db.SaveChanges();
                }
            }
            catch { }

            // 4. Ensure all user passwords have their plain password populated for Developer view and management
            try
            {
                var users = db.Users.ToList();
                var hasher = new PasswordHasher();
                bool changed = false;

                foreach (var u in users)
                {
                    if (string.IsNullOrEmpty(u.PlainPassword))
                    {
                        if (u.Username == "dev") u.PlainPassword = "dev123";
                        else if (u.Username == "admin") u.PlainPassword = "admin123";
                        else if (u.Role == UserRole.Teacher || u.Username == "ahmad" || u.Username == "khaled") u.PlainPassword = "teacher123";
                        else if (u.Role == UserRole.ExamSupervisor || u.Username == "wael") u.PlainPassword = "exam123";
                        else if (u.Role == UserRole.Parent) u.PlainPassword = "parent123";
                        else if (u.Role == UserRole.Student) u.PlainPassword = "student123";
                        else u.PlainPassword = "123456";
                        changed = true;
                    }

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

