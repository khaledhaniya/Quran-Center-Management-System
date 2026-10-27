using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Data;

public static partial class DbSeeder
{
    public static void Seed(AppDbContext db, PasswordHasher hasher, PasswordVault? vault = null)
    {
        // Initial privileged accounts are created only with administrator-supplied secrets.
        foreach (var (username, role, variable, fullName) in new[] {
            ("admin", UserRole.Admin, "BOOTSTRAP_ADMIN_PASSWORD", "مدير المركز"),
            ("dev", UserRole.Developer, "BOOTSTRAP_DEVELOPER_PASSWORD", "مطور النظام") })
        {
            var password = Environment.GetEnvironmentVariable(variable);
            if (!db.Users.Any(u => u.Username == username) && !string.IsNullOrWhiteSpace(password))
            {
                if (password.Length < 12) throw new InvalidOperationException($"{variable} must contain at least 12 characters.");
                db.Users.Add(new User { Username = username, FullName = fullName,
                    Role = role, IsActive = true, PasswordHash = hasher.HashPassword(password),
                    PasswordCiphertext = vault?.Protect(password) ?? string.Empty });
            }
        }
        db.SaveChanges();

        // 2. استيراد بيانات الطلاب الأساسية لمرة واحدة فقط إذا كان جدول الطلاب فارغاً
        // Operational data is entered/imported explicitly, never restored on startup.
    }

    public static void MigrateSchema(AppDbContext db)
    {
        var provider = db.Database.ProviderName ?? "";
        bool isSqlServer = provider.Contains("SqlServer", StringComparison.OrdinalIgnoreCase);
        bool isSqlite = provider.Contains("Sqlite", StringComparison.OrdinalIgnoreCase);

        EnsurePasswordVaultSchema(db);

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

        EnsureIdempotencySchema(db);
        OperationsSchema.Ensure(db);

        // Provider-agnostic migrations (EF Core based)
        EnsureSystemSettings(db);
        EnsureUserPasswordHashes(db);
        // Never recreate removed staff, students, or demo activity during deployment.

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
            ("Notes", "NVARCHAR(MAX) NULL"),
            ("PlanNotes", "NVARCHAR(MAX) NULL")
        };

        foreach (var (colName, colType) in studentColumns)
        {
            try
            {
                ExecuteSchemaSql(db, $@"
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
                ExecuteSchemaSql(db, $@"
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

        // 4.5 Ensure ExamNominations.TeacherId is nullable for safe cascading
        try
        {
            db.Database.ExecuteSqlRaw(@"
                IF EXISTS (
                    SELECT 1 FROM sys.columns
                    WHERE object_id = OBJECT_ID(N'[ExamNominations]') AND name = 'TeacherId' AND is_nullable = 0
                )
                BEGIN
                    ALTER TABLE [ExamNominations] ALTER COLUMN [TeacherId] INT NULL;
                END
            ");
        }
        catch (Exception ex) { Console.WriteLine($"[SqlServer Migration] ExamNominations.TeacherId: {ex.Message}"); }

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
            ("EnableRecitationIncompleteAlert", "BIT NOT NULL DEFAULT 1"),
            ("RecitationAlertTemplate", "NVARCHAR(MAX) NULL"),
            ("MaintenanceMode", "BIT NOT NULL DEFAULT 0"),
            ("UpdatedAt", "DATETIME2 NOT NULL DEFAULT GETUTCDATE()")
        };

        foreach (var (colName, colType) in settingsColumns)
        {
            try
            {
                ExecuteSchemaSql(db, $@"
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
            ("Notes", "TEXT"),
            ("PlanNotes", "TEXT")
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
                    ExecuteSchemaSql(db, $"ALTER TABLE Students ADD COLUMN {colName} {colType};");
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
                    ExecuteSchemaSql(db, $"ALTER TABLE Teachers ADD COLUMN {colName} {colType};");
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
                { "EnableRecitationIncompleteAlert", "INTEGER NOT NULL DEFAULT 1" },
                { "RecitationAlertTemplate", "TEXT" },
                { "MaintenanceMode", "INTEGER NOT NULL DEFAULT 0" },
                { "UpdatedAt", "TEXT NOT NULL DEFAULT '2026-01-01T00:00:00Z'" }
            };

            foreach (var (colName, colType) in settingsColumns)
            {
                if (!existingSettingsCols.Contains(colName))
                {
                    try
                    {
                        ExecuteSchemaSql(db, $"ALTER TABLE SystemSettings ADD COLUMN {colName} {colType};");
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

        // Ensure QualityVisits table exists
        try
        {
            db.Database.ExecuteSqlRaw(@"
                CREATE TABLE IF NOT EXISTS QualityVisits (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    CircleId INTEGER NOT NULL,
                    SupervisorName TEXT NOT NULL,
                    VisitDate TEXT NOT NULL,
                    PunctualityScore INTEGER NOT NULL DEFAULT 100,
                    ClassManagementScore INTEGER NOT NULL DEFAULT 100,
                    TajweedCorrectionScore INTEGER NOT NULL DEFAULT 100,
                    OverallQualityScore INTEGER NOT NULL DEFAULT 100,
                    Notes TEXT,
                    SpotCheckedStudentsJson TEXT,
                    IsSubstituteModeActive INTEGER NOT NULL DEFAULT 0,
                    CreatedAt TEXT NOT NULL,
                    FOREIGN KEY (CircleId) REFERENCES Circles(Id) ON DELETE CASCADE
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

    private static void ExecuteSchemaSql(AppDbContext db, string sql)
    {
        // Only this class's fixed column/type lists call this method; never request input.
        // Validate the statements against DDL delimiters to guard future call sites.
        if (sql.Contains("--") || sql.Contains("/*") || sql.Contains("*/"))
            throw new ArgumentException("Unsupported schema SQL.");
#pragma warning disable EF1002
        db.Database.ExecuteSqlRaw(sql);
#pragma warning restore EF1002
    }

    private static void EnsurePasswordVaultSchema(AppDbContext db)
    {
        if (db.Database.IsSqlServer())
            db.Database.ExecuteSqlRaw("IF COL_LENGTH('Users', 'PasswordCiphertext') IS NULL ALTER TABLE Users ADD PasswordCiphertext nvarchar(max) NOT NULL DEFAULT ''");
        else if (db.Database.IsNpgsql())
            db.Database.ExecuteSqlRaw("ALTER TABLE \"Users\" ADD COLUMN IF NOT EXISTS \"PasswordCiphertext\" text NOT NULL DEFAULT ''");
        else
        {
            try
            {
                if (db.Database.SqlQueryRaw<int>("SELECT COUNT(*) AS Value FROM pragma_table_info('Users') WHERE name = 'PasswordCiphertext'").Single() == 0)
                    db.Database.ExecuteSqlRaw("ALTER TABLE Users ADD COLUMN PasswordCiphertext TEXT NOT NULL DEFAULT ''");
            }
            catch (Microsoft.Data.Sqlite.SqliteException ex) when (ex.Message.Contains("duplicate column name", StringComparison.OrdinalIgnoreCase)) { }
        }
    }

    private static void EnsureIdempotencySchema(AppDbContext db)
    {
        if (db.Database.IsSqlServer())
            db.Database.ExecuteSqlRaw("IF COL_LENGTH('Users', 'TokenVersion') IS NULL ALTER TABLE Users ADD TokenVersion int NOT NULL DEFAULT 0");
        else if (db.Database.IsNpgsql())
            db.Database.ExecuteSqlRaw("ALTER TABLE \"Users\" ADD COLUMN IF NOT EXISTS \"TokenVersion\" integer NOT NULL DEFAULT 0");
        else
        {
            try {
                if (db.Database.SqlQueryRaw<int>("SELECT COUNT(*) AS Value FROM pragma_table_info('Users') WHERE name = 'TokenVersion'").Single() == 0)
                    db.Database.ExecuteSqlRaw("ALTER TABLE Users ADD COLUMN TokenVersion INTEGER NOT NULL DEFAULT 0");
            }
            catch (Microsoft.Data.Sqlite.SqliteException ex) when (ex.Message.Contains("duplicate column name", StringComparison.OrdinalIgnoreCase)) { }
        }

        if (db.Database.IsSqlServer())
            db.Database.ExecuteSqlRaw(@"IF OBJECT_ID(N'IdempotencyReceipts', N'U') IS NULL
                CREATE TABLE IdempotencyReceipts (Id nvarchar(64) NOT NULL PRIMARY KEY,
                RequestHash nvarchar(64) NOT NULL, ResponseJson nvarchar(max) NOT NULL,
                StatusCode int NOT NULL, CreatedAt datetime2 NOT NULL)");
        else if (db.Database.IsNpgsql())
            db.Database.ExecuteSqlRaw("CREATE TABLE IF NOT EXISTS \"IdempotencyReceipts\" (\"Id\" text PRIMARY KEY, \"RequestHash\" text NOT NULL, \"ResponseJson\" text NOT NULL, \"StatusCode\" integer NOT NULL, \"CreatedAt\" timestamp with time zone NOT NULL)");
        else
            db.Database.ExecuteSqlRaw("CREATE TABLE IF NOT EXISTS IdempotencyReceipts (Id TEXT NOT NULL PRIMARY KEY, RequestHash TEXT NOT NULL, ResponseJson TEXT NOT NULL, StatusCode INTEGER NOT NULL, CreatedAt TEXT NOT NULL)");
    }

    private static void EnsureUserPasswordHashes(AppDbContext db)
    {
        var hasher = new PasswordHasher();
        foreach (var user in db.Users.Where(u => u.PlainPassword != "").ToList())
        {
            if (string.IsNullOrEmpty(user.PasswordHash))
                user.PasswordHash = hasher.HashPassword(user.PlainPassword);
            user.PlainPassword = string.Empty;
        }
        db.SaveChanges();
    }

}
