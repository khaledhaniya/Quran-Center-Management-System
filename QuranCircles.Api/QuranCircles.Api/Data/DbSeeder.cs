using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Data;

public static partial class DbSeeder
{
    public static void Seed(AppDbContext db, PasswordHasher hasher)
    {
        // 1. إضافة المستخدمين الإداريين الأساسيين (المدير، المطور، والمشرف) في حال عدم وجودهم
        if (!db.Users.Any(u => u.Username.ToLower() == "admin"))
        {
            db.Users.Add(new User 
            { 
                Username = "admin", 
                PasswordHash = hasher.HashPassword("admin123"), 
                PlainPassword = "admin123",
                Role = UserRole.Admin, 
                FullName = "مدير المركز", 
                IsActive = true 
            });
        }

        if (!db.Users.Any(u => u.Username.ToLower() == "dev"))
        {
            db.Users.Add(new User 
            { 
                Username = "dev", 
                PasswordHash = hasher.HashPassword("dev123"), 
                PlainPassword = "dev123",
                Role = UserRole.Developer, 
                FullName = "مطور النظام", 
                IsActive = true 
            });
        }

        if (!db.Users.Any(u => u.Username.ToLower() == "wael"))
        {
            db.Users.Add(new User
            {
                Username = "wael",
                PasswordHash = hasher.HashPassword("wael123"),
                PlainPassword = "wael123",
                Role = UserRole.ExamSupervisor,
                FullName = "المشرف وائل هلية",
                IsActive = true
            });
        }
        db.SaveChanges();

        // 2. استيراد بيانات الطلاب الأساسية لمرة واحدة فقط إذا كان جدول الطلاب فارغاً
        SeedStudents(db, hasher);
    }

    public static void MigrateSchema(AppDbContext db)
    {
        var provider = db.Database.ProviderName ?? "";
        bool isSqlServer = provider.Contains("SqlServer", StringComparison.OrdinalIgnoreCase);
        bool isSqlite = provider.Contains("Sqlite", StringComparison.OrdinalIgnoreCase);

        try
        {
            if (isSqlServer)
            {
                Console.WriteLine("[Database] 🔄 Running SQL Server schema migration on MonsterASP...");
                MigrateSqlServer(db);
            }
            else
            {
                Console.WriteLine("[Database] 🔄 Running SQLite schema migration...");
                MigrateSqlite(db);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Schema Migration Notice] {ex.Message}");
        }

        // Provider-agnostic migrations (EF Core based)
        EnsureSystemSettings(db);
        EnsureUserPasswordHashes(db);
        EnsureSeedTeachers(db);
        EnsureSeedTalents(db);
        EnsureSeedHuffaz(db);

        if (isSqlite)
        {
            try
            {
                db.Database.ExecuteSqlRaw("PRAGMA wal_checkpoint(TRUNCATE);");
            }
            catch { }
        }
    }

    private static void MigrateSqlServer(AppDbContext db)
    {
        // 1. Sessions table - RecitationType
        try
        {
            db.Database.ExecuteSqlRaw(@"
                IF NOT EXISTS (
                    SELECT 1 FROM sys.columns 
                    WHERE object_id = OBJECT_ID(N'[Sessions]') AND name = 'RecitationType'
                )
                BEGIN
                    ALTER TABLE [Sessions] ADD [RecitationType] INT NOT NULL DEFAULT 1;
                END
            ");
        }
        catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] Sessions.RecitationType: {ex.Message}"); }

        // 2. Circles table - AssistantTeacherId
        try
        {
            db.Database.ExecuteSqlRaw(@"
                IF NOT EXISTS (
                    SELECT 1 FROM sys.columns 
                    WHERE object_id = OBJECT_ID(N'[Circles]') AND name = 'AssistantTeacherId'
                )
                BEGIN
                    ALTER TABLE [Circles] ADD [AssistantTeacherId] INT NULL;
                END
            ");
        }
        catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] Circles.AssistantTeacherId: {ex.Message}"); }

        // 3. Students table missing columns
        var studentColumns = new (string Name, string Type)[]
        {
            ("TargetAjzaaCount", "INT NOT NULL DEFAULT 30"),
            ("PlanType", "NVARCHAR(100) NULL"),
            ("PlanStartDate", "DATE NULL"),
            ("PlanTargetDate", "DATE NULL"),
            ("DailyPacePages", "FLOAT NOT NULL DEFAULT 1.0"),
            ("CompletedAjzaa", "NVARCHAR(MAX) NULL"),
            ("StudentIdentityNumber", "NVARCHAR(50) NULL"),
            ("PreviousQuranMemorization", "NVARCHAR(MAX) NULL"),
            ("StudentMobile", "NVARCHAR(50) NULL"),
            ("StudentWhatsapp", "NVARCHAR(50) NULL"),
            ("HealthStatus", "NVARCHAR(MAX) NULL"),
            ("FatherStatus", "NVARCHAR(100) NULL"),
            ("MotherStatus", "NVARCHAR(100) NULL"),
            ("Kinship", "NVARCHAR(100) NULL"),
            ("ParentIdentityNumber", "NVARCHAR(50) NULL"),
            ("WhatsappNumber", "NVARCHAR(50) NULL"),
            ("WalletNumber", "NVARCHAR(50) NULL"),
            ("BankAccountNumber", "NVARCHAR(50) NULL"),
            ("BankName", "NVARCHAR(100) NULL"),
            ("OriginalAddress", "NVARCHAR(255) NULL"),
            ("OriginalHousingType", "NVARCHAR(100) NULL"),
            ("OriginalHousingStatus", "NVARCHAR(100) NULL"),
            ("CurrentAddress", "NVARCHAR(255) NULL"),
            ("CurrentHousingType", "NVARCHAR(100) NULL"),
            ("Notes", "NVARCHAR(MAX) NULL")
        };

        foreach (var (colName, colType) in studentColumns)
        {
            try
            {
                db.Database.ExecuteSqlRaw($@"
                    IF NOT EXISTS (
                        SELECT 1 FROM sys.columns 
                        WHERE object_id = OBJECT_ID(N'[Students]') AND name = '{colName}'
                    )
                    BEGIN
                        ALTER TABLE [Students] ADD [{colName}] {colType};
                    END
                ");
            }
            catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] Students.{colName}: {ex.Message}"); }
        }

        // 4. Teachers table missing columns
        var teacherColumns = new (string Name, string Type)[]
        {
            ("IdentityNumber", "NVARCHAR(50) NULL"),
            ("WhatsappNumber", "NVARCHAR(50) NULL"),
            ("SocialStatus", "NVARCHAR(100) NULL"),
            ("FamilyMembersCount", "INT NULL"),
            ("MosqueName", "NVARCHAR(255) NULL"),
            ("Qualification", "NVARCHAR(255) NULL"),
            ("TaskRole", "NVARCHAR(255) NULL"),
            ("WalletNumber", "NVARCHAR(50) NULL"),
            ("WalletOwner", "NVARCHAR(255) NULL"),
            ("MemorizedAjzaa", "NVARCHAR(255) NULL"),
            ("StudentsCountTarget", "NVARCHAR(50) NULL")
        };

        foreach (var (colName, colType) in teacherColumns)
        {
            try
            {
                db.Database.ExecuteSqlRaw($@"
                    IF NOT EXISTS (
                        SELECT 1 FROM sys.columns 
                        WHERE object_id = OBJECT_ID(N'[Teachers]') AND name = '{colName}'
                    )
                    BEGIN
                        ALTER TABLE [Teachers] ADD [{colName}] {colType};
                    END
                ");
            }
            catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] Teachers.{colName}: {ex.Message}"); }
        }

        // 5. FinancialTransactions table
        try
        {
            db.Database.ExecuteSqlRaw(@"
                IF OBJECT_ID(N'[FinancialTransactions]', N'U') IS NULL
                BEGIN
                    CREATE TABLE [FinancialTransactions] (
                        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        [Type] INT NOT NULL,
                        [Amount] DECIMAL(18,2) NOT NULL,
                        [Currency] NVARCHAR(50) NOT NULL DEFAULT 'ILS',
                        [Title] NVARCHAR(255) NOT NULL,
                        [Category] NVARCHAR(100) NULL,
                        [DonorName] NVARCHAR(255) NULL,
                        [DonorSource] NVARCHAR(255) NULL,
                        [RecipientName] NVARCHAR(255) NULL,
                        [PaymentMethod] INT NOT NULL,
                        [PaymentDetails] NVARCHAR(MAX) NULL,
                        [TransactionDate] DATETIME2 NOT NULL,
                        [ReferenceNumber] NVARCHAR(100) NULL,
                        [Notes] NVARCHAR(MAX) NULL,
                        [CreatedByUserId] INT NULL,
                        [CreatedByName] NVARCHAR(255) NULL,
                        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE()
                    );
                END
            ");
        }
        catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] FinancialTransactions: {ex.Message}"); }

        // 6. TalentRecords table
        try
        {
            db.Database.ExecuteSqlRaw(@"
                IF OBJECT_ID(N'[TalentRecords]', N'U') IS NULL
                BEGIN
                    CREATE TABLE [TalentRecords] (
                        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        [StudentId] INT NOT NULL,
                        [TalentType] NVARCHAR(100) NOT NULL,
                        [Title] NVARCHAR(255) NOT NULL,
                        [PreparationMethod] NVARCHAR(MAX) NULL,
                        [SpeechContent] NVARCHAR(MAX) NULL,
                        [Occasion] NVARCHAR(255) NULL,
                        [EventDate] DATE NOT NULL,
                        [SupervisorTeacherId] INT NULL,
                        [MediaUrl] NVARCHAR(MAX) NULL,
                        [MediaType] NVARCHAR(50) NULL DEFAULT 'video',
                        [EvaluationScore] NVARCHAR(50) NULL,
                        [PerformanceNotes] NVARCHAR(MAX) NULL,
                        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE()
                    );
                END
            ");
        }
        catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] TalentRecords: {ex.Message}"); }

        // 7. HuffazMembers table
        try
        {
            db.Database.ExecuteSqlRaw(@"
                IF OBJECT_ID(N'[HuffazMembers]', N'U') IS NULL
                BEGIN
                    CREATE TABLE [HuffazMembers] (
                        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        [MemberType] NVARCHAR(50) NOT NULL DEFAULT 'Student',
                        [TeacherId] INT NULL,
                        [StudentId] INT NULL,
                        [FullName] NVARCHAR(255) NOT NULL,
                        [IdentityNumber] NVARCHAR(50) NULL,
                        [PhoneNumber] NVARCHAR(50) NULL,
                        [MemorizedAjzaaCount] INT NOT NULL DEFAULT 30,
                        [IsKhatim] BIT NOT NULL DEFAULT 1,
                        [Riwayah] NVARCHAR(100) NULL,
                        [SupervisorTeacherId] INT NULL,
                        [RevisionPlan] NVARCHAR(MAX) NULL,
                        [Notes] NVARCHAR(MAX) NULL,
                        [JoinDate] DATE NOT NULL,
                        [IsActive] BIT NOT NULL DEFAULT 1,
                        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE()
                    );
                END
            ");
        }
        catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] HuffazMembers: {ex.Message}"); }

        // 8. ProfileUpdateRequests table
        try
        {
            db.Database.ExecuteSqlRaw(@"
                IF OBJECT_ID(N'[ProfileUpdateRequests]', N'U') IS NULL
                BEGIN
                    CREATE TABLE [ProfileUpdateRequests] (
                        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        [UserId] INT NOT NULL,
                        [StudentId] INT NULL,
                        [RequestedByRole] NVARCHAR(50) NOT NULL DEFAULT 'Student',
                        [RequestedByName] NVARCHAR(255) NOT NULL DEFAULT '',
                        [ChangesJson] NVARCHAR(MAX) NOT NULL DEFAULT '',
                        [Status] NVARCHAR(50) NOT NULL DEFAULT 'Pending',
                        [RequestDate] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
                        [ReviewerNotes] NVARCHAR(MAX) NULL,
                        [ReviewDate] DATETIME2 NULL
                    );
                END
            ");
        }
        catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] ProfileUpdateRequests: {ex.Message}"); }

        // 9. SystemSettings table and columns
        try
        {
            db.Database.ExecuteSqlRaw(@"
                IF OBJECT_ID(N'[SystemSettings]', N'U') IS NULL
                BEGIN
                    CREATE TABLE [SystemSettings] (
                        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        [CenterName] NVARCHAR(255) NULL,
                        [MosqueName] NVARCHAR(255) NULL,
                        [CenterAddress] NVARCHAR(255) NULL,
                        [SupportPhone] NVARCHAR(50) NULL,
                        [SupportEmail] NVARCHAR(100) NULL,
                        [WelcomeMessage] NVARCHAR(MAX) NULL,
                        [LogoUrl] NVARCHAR(MAX) NULL,
                        [ThemeStyle] NVARCHAR(50) NULL,
                        [PassingScoreThreshold] INT NOT NULL DEFAULT 70,
                        [MinAttendancePercentForExam] INT NOT NULL DEFAULT 75,
                        [MaxStudentsPerCircle] INT NOT NULL DEFAULT 20,
                        [MaxAbsenceDaysWarning] INT NOT NULL DEFAULT 3,
                        [AllowTeacherEditStudentPlan] BIT NOT NULL DEFAULT 1,
                        [AllowTeacherSelfEnrollment] BIT NOT NULL DEFAULT 1,
                        [HideParentPhoneFromTeacher] BIT NOT NULL DEFAULT 0,
                        [AllowStudentProfileEditRequests] BIT NOT NULL DEFAULT 1,
                        [EnforceDailyAttendanceRecording] BIT NOT NULL DEFAULT 1,
                        [ShowStudentCountToTeacher] BIT NOT NULL DEFAULT 1,
                        [ShowCumulativeAttendance] BIT NOT NULL DEFAULT 1,
                        [EnableCertificates] BIT NOT NULL DEFAULT 1,
                        [SignatoryName] NVARCHAR(255) NULL,
                        [SignatoryTitle] NVARCHAR(255) NULL,
                        [ShowHonorsBoard] BIT NOT NULL DEFAULT 1,
                        [AllowPublicAnnouncements] BIT NOT NULL DEFAULT 1,
                        [EnableAbsenceAutoAlert] BIT NOT NULL DEFAULT 1,
                        [AbsenceAlertTemplate] NVARCHAR(MAX) NULL,
                        [MaintenanceMode] BIT NOT NULL DEFAULT 0,
                        [UpdatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE()
                    );
                END
            ");
        }
        catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] SystemSettings: {ex.Message}"); }

        var settingsColumns = new (string Name, string Type)[]
        {
            ("CenterName", "NVARCHAR(255) NULL"),
            ("MosqueName", "NVARCHAR(255) NULL"),
            ("CenterAddress", "NVARCHAR(255) NULL"),
            ("SupportPhone", "NVARCHAR(50) NULL"),
            ("SupportEmail", "NVARCHAR(100) NULL"),
            ("WelcomeMessage", "NVARCHAR(MAX) NULL"),
            ("LogoUrl", "NVARCHAR(MAX) NULL"),
            ("ThemeStyle", "NVARCHAR(50) NULL"),
            ("PassingScoreThreshold", "INT NOT NULL DEFAULT 70"),
            ("MinAttendancePercentForExam", "INT NOT NULL DEFAULT 75"),
            ("MaxStudentsPerCircle", "INT NOT NULL DEFAULT 20"),
            ("MaxAbsenceDaysWarning", "INT NOT NULL DEFAULT 3"),
            ("AllowTeacherEditStudentPlan", "BIT NOT NULL DEFAULT 1"),
            ("AllowTeacherSelfEnrollment", "BIT NOT NULL DEFAULT 1"),
            ("HideParentPhoneFromTeacher", "BIT NOT NULL DEFAULT 0"),
            ("AllowStudentProfileEditRequests", "BIT NOT NULL DEFAULT 1"),
            ("EnforceDailyAttendanceRecording", "BIT NOT NULL DEFAULT 1"),
            ("ShowStudentCountToTeacher", "BIT NOT NULL DEFAULT 1"),
            ("ShowCumulativeAttendance", "BIT NOT NULL DEFAULT 1"),
            ("EnableCertificates", "BIT NOT NULL DEFAULT 1"),
            ("SignatoryName", "NVARCHAR(255) NULL"),
            ("SignatoryTitle", "NVARCHAR(255) NULL"),
            ("ShowHonorsBoard", "BIT NOT NULL DEFAULT 1"),
            ("AllowPublicAnnouncements", "BIT NOT NULL DEFAULT 1"),
            ("EnableAbsenceAutoAlert", "BIT NOT NULL DEFAULT 1"),
            ("AbsenceAlertTemplate", "NVARCHAR(MAX) NULL"),
            ("MaintenanceMode", "BIT NOT NULL DEFAULT 0"),
            ("UpdatedAt", "DATETIME2 NOT NULL DEFAULT GETUTCDATE()")
        };

        foreach (var (colName, colType) in settingsColumns)
        {
            try
            {
                db.Database.ExecuteSqlRaw($@"
                    IF NOT EXISTS (
                        SELECT 1 FROM sys.columns 
                        WHERE object_id = OBJECT_ID(N'[SystemSettings]') AND name = '{colName}'
                    )
                    BEGIN
                        ALTER TABLE [SystemSettings] ADD [{colName}] {colType};
                    END
                ");
            }
            catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] Settings.{colName}: {ex.Message}"); }
        }
    }

    private static void MigrateSqlite(AppDbContext db)
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

        // Ensure Sessions table has RecitationType column
        try
        {
            db.Database.ExecuteSqlRaw("ALTER TABLE Sessions ADD COLUMN RecitationType INTEGER DEFAULT 1;");
        }
        catch { /* Column already exists */ }

        // Ensure FinancialTransactions table exists
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

        // Ensure SystemSettings table exists and has all new columns
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

        // Ensure TalentRecords table exists
        try
        {
            db.Database.ExecuteSqlRaw(@"
                CREATE TABLE IF NOT EXISTS TalentRecords (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    StudentId INTEGER NOT NULL,
                    TalentType TEXT NOT NULL,
                    Title TEXT NOT NULL,
                    PreparationMethod TEXT,
                    SpeechContent TEXT,
                    Occasion TEXT,
                    EventDate TEXT NOT NULL,
                    SupervisorTeacherId INTEGER,
                    MediaUrl TEXT,
                    MediaType TEXT DEFAULT 'video',
                    EvaluationScore TEXT,
                    PerformanceNotes TEXT,
                    CreatedAt TEXT NOT NULL,
                    FOREIGN KEY (StudentId) REFERENCES Students(Id) ON DELETE CASCADE,
                    FOREIGN KEY (SupervisorTeacherId) REFERENCES Teachers(Id) ON DELETE SET NULL
                );
            ");
        }
        catch { }

        // Ensure HuffazMembers table exists
        try
        {
            db.Database.ExecuteSqlRaw(@"
                CREATE TABLE IF NOT EXISTS HuffazMembers (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    MemberType TEXT NOT NULL DEFAULT 'Student',
                    TeacherId INTEGER,
                    StudentId INTEGER,
                    FullName TEXT NOT NULL,
                    IdentityNumber TEXT,
                    PhoneNumber TEXT,
                    MemorizedAjzaaCount INTEGER NOT NULL DEFAULT 30,
                    IsKhatim INTEGER NOT NULL DEFAULT 1,
                    Riwayah TEXT,
                    SupervisorTeacherId INTEGER,
                    RevisionPlan TEXT,
                    Notes TEXT,
                    JoinDate TEXT NOT NULL,
                    IsActive INTEGER NOT NULL DEFAULT 1,
                    CreatedAt TEXT NOT NULL,
                    FOREIGN KEY (TeacherId) REFERENCES Teachers(Id) ON DELETE SET NULL,
                    FOREIGN KEY (StudentId) REFERENCES Students(Id) ON DELETE SET NULL,
                    FOREIGN KEY (SupervisorTeacherId) REFERENCES Teachers(Id) ON DELETE SET NULL
                );
            ");
        }
        catch { }
    }

    private static void EnsureSystemSettings(AppDbContext db)
    {
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
        catch (Exception ex)
        {
            Console.WriteLine($"[Settings Sync Notice] {ex.Message}");
        }
    }

    private static void EnsureUserPasswordHashes(AppDbContext db)
    {
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

    private static void EnsureSeedTeachers(AppDbContext db)
    {
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
    }

    private static void EnsureSeedTalents(AppDbContext db)
    {
        try
        {
            if (!db.TalentRecords.Any())
            {
                var student1 = db.Students.Include(s => s.Circle).FirstOrDefault();
                var student2 = db.Students.Include(s => s.Circle).Skip(1).FirstOrDefault();
                var teacher = db.Teachers.FirstOrDefault();

                if (student1 != null)
                {
                    db.TalentRecords.Add(new QuranCircles.Api.Entities.TalentRecord
                    {
                        StudentId = student1.Id,
                        TalentType = "الفتى الواعظ (فن الخطابة والوعظ)",
                        Title = "بر الوالدين وأثره في توفيق العبد وصلاحه",
                        PreparationMethod = "بحث ومطالعة ذاتية مع إشراف وتدريب من الشيخ المحفظ",
                        SpeechContent = "الحمد لله الذي وصانا بالوالدين إحسانا، وجعل رضاهما من رضاه سبحانه وتعالى. أيها الإخوة الكرام، إن بر الوالدين طاعة لله وقربة، ومفتاح لكل خير وبركة في الدنيا والآخرة...",
                        Occasion = "درس الجمعة الأسبوعي في المسجد",
                        EventDate = DateOnly.FromDateTime(DateTime.Today),
                        SupervisorTeacherId = teacher?.Id,
                        MediaUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                        MediaType = "video",
                        EvaluationScore = "95%",
                        PerformanceNotes = "فصاحة ممتازة، نبرة واثقة، ومخارج حروف متقنة ومؤثرة تبارك الله.",
                        CreatedAt = DateTime.UtcNow
                    });
                }

                if (student2 != null)
                {
                    db.TalentRecords.Add(new QuranCircles.Api.Entities.TalentRecord
                    {
                        StudentId = student2.Id,
                        TalentType = "أصوات ندية (تلاوة القرآن)",
                        Title = "تلاوة خاشعة مرتلة من سورة الرحمن",
                        PreparationMethod = "مقرأة الصوت والخشوع وضبط المقامات القرآنية",
                        SpeechContent = "ترتيل وتجويد سورة الرحمن بصوت ندي ومتقن في حلقة المساء",
                        Occasion = "المسابقة القرآنية الرمضانية",
                        EventDate = DateOnly.FromDateTime(DateTime.Today),
                        SupervisorTeacherId = teacher?.Id,
                        MediaUrl = "",
                        MediaType = "audio",
                        EvaluationScore = "98%",
                        PerformanceNotes = "صوت ندي مؤثر وخشوع رائع مع التزام تام بأحكام التجويد والمدود.",
                        CreatedAt = DateTime.UtcNow
                    });
                }

                db.SaveChanges();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Seeder Notice] Seeding Talents: {ex.Message}");
        }
    }

    private static void EnsureSeedHuffaz(AppDbContext db)
    {
        try
        {
            if (!db.HuffazMembers.Any())
            {
                var teacher = db.Teachers.FirstOrDefault();
                var student = db.Students.FirstOrDefault();

                if (teacher != null)
                {
                    db.HuffazMembers.Add(new QuranCircles.Api.Entities.HuffazMember
                    {
                        MemberType = "Teacher",
                        TeacherId = teacher.Id,
                        FullName = teacher.FullName,
                        IdentityNumber = teacher.IdentityNumber,
                        PhoneNumber = teacher.Contact,
                        MemorizedAjzaaCount = 30,
                        IsKhatim = true,
                        Riwayah = "حفص عن عاصم من طريق الشاطبية",
                        SupervisorTeacherId = teacher.Id,
                        RevisionPlan = "مراجعة 3 أجزاء يومياً وتثبيت الإتقان مع مشايخ السند",
                        Notes = "شيخ ومعلم بالمركز مجاز بالقراءات ويشرف على الحفاظ",
                        JoinDate = DateOnly.FromDateTime(DateTime.Today),
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    });
                }

                if (student != null)
                {
                    db.HuffazMembers.Add(new QuranCircles.Api.Entities.HuffazMember
                    {
                        MemberType = "Student",
                        StudentId = student.Id,
                        FullName = student.FullName,
                        IdentityNumber = student.StudentIdentityNumber ?? "400111222",
                        PhoneNumber = student.StudentMobile ?? student.FamilyContact,
                        MemorizedAjzaaCount = 25,
                        IsKhatim = false,
                        Riwayah = "حفص عن عاصم",
                        SupervisorTeacherId = teacher?.Id,
                        RevisionPlan = "تثبيت الأجزاء الخمسة الأخيرة لبلوغ الختمة المباركة قريباً",
                        Notes = "طالب متميز في حفظ القرآن ومواظب في الحلقة",
                        JoinDate = DateOnly.FromDateTime(DateTime.Today),
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    });
                }

                db.HuffazMembers.Add(new QuranCircles.Api.Entities.HuffazMember
                {
                    MemberType = "External",
                    FullName = "بلال محمود سالم قاسم",
                    IdentityNumber = "401928374",
                    PhoneNumber = "+970599112233",
                    MemorizedAjzaaCount = 30,
                    IsKhatim = true,
                    Riwayah = "قراءة عاصم بروايتي شعبة وحفص",
                    SupervisorTeacherId = teacher?.Id,
                    RevisionPlan = "جلسة تثبيت أسبوعية كل يوم جمعة بعد صلاة الفجر",
                    Notes = "حافظ خارجي منتسب لمنتدى الحفاظ ومتميز في الضبط والإتقان",
                    JoinDate = DateOnly.FromDateTime(DateTime.Today),
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                });

                db.SaveChanges();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Seeder Notice] Seeding Huffaz: {ex.Message}");
        }
    }
}
