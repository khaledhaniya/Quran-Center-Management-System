using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<CirclePlan> CirclePlans => Set<CirclePlan>();
    public DbSet<CircleSchedule> CircleSchedules => Set<CircleSchedule>();
    public DbSet<CircleDay> CircleDays => Set<CircleDay>();
    public DbSet<Student> Students => Set<Student>();
    public DbSet<IdempotencyReceipt> IdempotencyReceipts => Set<IdempotencyReceipt>();
    public DbSet<Teacher> Teachers => Set<Teacher>();
    public DbSet<Circle> Circles => Set<Circle>();
    public DbSet<RecitationSession> Sessions => Set<RecitationSession>();
    public DbSet<Attendance> Attendances => Set<Attendance>();
    public DbSet<User> Users => Set<User>();
    public DbSet<Announcement> Announcements => Set<Announcement>();
    public DbSet<Course> Courses => Set<Course>();
    public DbSet<CourseEnrollment> CourseEnrollments => Set<CourseEnrollment>();
    public DbSet<HadithSession> HadithSessions => Set<HadithSession>();
    public DbSet<ExamNomination> ExamNominations => Set<ExamNomination>();
    public DbSet<ExamResult> ExamResults => Set<ExamResult>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<CourseAttendance> CourseAttendances => Set<CourseAttendance>();
    public DbSet<ProfileUpdateRequest> ProfileUpdateRequests => Set<ProfileUpdateRequest>();
    public DbSet<SystemSettings> SystemSettings => Set<SystemSettings>();
    public DbSet<FinancialTransaction> FinancialTransactions => Set<FinancialTransaction>();
    public DbSet<TalentRecord> TalentRecords => Set<TalentRecord>();
    public DbSet<HuffazMember> HuffazMembers => Set<HuffazMember>();
    public DbSet<QualityVisit> QualityVisits => Set<QualityVisit>();

    private void RemovePlaintextPasswords()
    {
        var hasher = new QuranCircles.Api.Services.PasswordHasher();
        foreach (var entry in ChangeTracker.Entries<User>().Where(e => e.State is EntityState.Added or EntityState.Modified))
        {
            if (entry.State == EntityState.Modified &&
                ((entry.Property(u => u.IsActive).IsModified && !entry.Entity.IsActive) || entry.Property(u => u.Role).IsModified))
                entry.Entity.TokenVersion++;
            if (!string.IsNullOrEmpty(entry.Entity.PlainPassword))
            {
                if (string.IsNullOrEmpty(entry.Entity.PasswordHash))
                    entry.Entity.PasswordHash = hasher.HashPassword(entry.Entity.PlainPassword);
                entry.Entity.PlainPassword = string.Empty;
            }
        }
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        RemovePlaintextPasswords();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        RemovePlaintextPasswords();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<CircleSchedule>().HasIndex(x => x.CircleId).IsUnique();
        b.Entity<CircleDay>().HasIndex(x => new { x.CircleId, x.Date }).IsUnique();
        b.Entity<CirclePlan>().Property(x => x.Target).HasPrecision(12, 2);
        b.Entity<CirclePlan>().Property(x => x.Completed).HasPrecision(12, 2);
        b.Entity<User>()
            .HasIndex(u => u.Username)
            .IsUnique();

        b.Entity<User>()
            .HasOne(u => u.Teacher)
            .WithMany()
            .HasForeignKey(u => u.TeacherId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<User>()
            .HasOne(u => u.Student)
            .WithMany()
            .HasForeignKey(u => u.StudentId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<Circle>()
            .HasOne(c => c.Teacher)
            .WithMany(t => t.Circles)
            .HasForeignKey(c => c.TeacherId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<Circle>()
            .HasOne(c => c.AssistantTeacher)
            .WithMany()
            .HasForeignKey(c => c.AssistantTeacherId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<Student>()
            .HasOne(s => s.Circle)
            .WithMany(c => c.Students)
            .HasForeignKey(s => s.CircleId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<RecitationSession>()
            .HasOne(rs => rs.Student)
            .WithMany(s => s.Sessions)
            .HasForeignKey(rs => rs.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        b.Entity<Attendance>()
            .HasOne(a => a.Student)
            .WithMany(s => s.AttendanceRecords)
            .HasForeignKey(a => a.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        b.Entity<Attendance>()
            .HasOne(a => a.Circle)
            .WithMany()
            .HasForeignKey(a => a.CircleId)
            .OnDelete(DeleteBehavior.Restrict);

        // Map relationships for new entities
        b.Entity<Course>()
            .HasOne(c => c.Teacher)
            .WithMany()
            .HasForeignKey(c => c.TeacherId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<Course>()
            .HasOne(c => c.ExamSupervisor)
            .WithMany()
            .HasForeignKey(c => c.ExamSupervisorId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<CourseEnrollment>()
            .HasOne(ce => ce.Course)
            .WithMany(c => c.Enrollments)
            .HasForeignKey(ce => ce.CourseId)
            .OnDelete(DeleteBehavior.Restrict);

        b.Entity<CourseEnrollment>()
            .HasOne(ce => ce.Student)
            .WithMany()
            .HasForeignKey(ce => ce.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        b.Entity<HadithSession>()
            .HasOne(hs => hs.Student)
            .WithMany()
            .HasForeignKey(hs => hs.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        b.Entity<ExamNomination>()
            .HasOne(en => en.Student)
            .WithMany()
            .HasForeignKey(en => en.StudentId)
            .OnDelete(DeleteBehavior.Restrict);

        b.Entity<ExamNomination>()
            .HasOne(en => en.Teacher)
            .WithMany()
            .HasForeignKey(en => en.TeacherId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<ExamNomination>()
            .HasOne(en => en.Course)
            .WithMany()
            .HasForeignKey(en => en.CourseId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<ExamNomination>()
            .HasOne(en => en.Result)
            .WithOne(er => er.ExamNomination)
            .HasForeignKey<ExamResult>(er => er.ExamNominationId)
            .OnDelete(DeleteBehavior.Cascade);

        b.Entity<CourseAttendance>()
            .HasOne(ca => ca.Student)
            .WithMany()
            .HasForeignKey(ca => ca.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        b.Entity<CourseAttendance>()
            .HasOne(ca => ca.Course)
            .WithMany()
            .HasForeignKey(ca => ca.CourseId)
            .OnDelete(DeleteBehavior.Restrict);

        b.Entity<TalentRecord>()
            .HasOne(tr => tr.Student)
            .WithMany()
            .HasForeignKey(tr => tr.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        b.Entity<TalentRecord>()
            .HasOne(tr => tr.SupervisorTeacher)
            .WithMany()
            .HasForeignKey(tr => tr.SupervisorTeacherId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<HuffazMember>()
            .HasOne(hm => hm.Teacher)
            .WithMany()
            .HasForeignKey(hm => hm.TeacherId)
            .OnDelete(DeleteBehavior.SetNull);

        b.Entity<HuffazMember>()
            .HasOne(hm => hm.Student)
            .WithMany()
            .HasForeignKey(hm => hm.StudentId)
            .OnDelete(DeleteBehavior.Restrict);

        b.Entity<HuffazMember>()
            .HasOne(hm => hm.SupervisorTeacher)
            .WithMany()
            .HasForeignKey(hm => hm.SupervisorTeacherId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
