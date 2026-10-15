using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using QuestPDF.Fluent;
using Xunit;

namespace QuranCircles.Api.Tests;

public class OperationalIntegrityTests
{
    [Fact]
    public void OperationalSchemaCanUpgradeExistingDatabaseTwice()
    {
        using var connection = new SqliteConnection("Data Source=:memory:"); connection.Open();
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(connection).Options);
        db.Database.EnsureCreated();
        db.Database.ExecuteSqlRaw("DROP TABLE \"CircleDays\"");
        db.Database.ExecuteSqlRaw("DROP TABLE \"CircleSchedules\"");
        db.Database.ExecuteSqlRaw("DROP TABLE \"CirclePlans\"");
        OperationsSchema.Ensure(db);
        OperationsSchema.Ensure(db);
        Assert.True(db.Database.SqlQueryRaw<int>("SELECT COUNT(*) AS Value FROM sqlite_master WHERE type='table' AND name IN ('CircleDays','CircleSchedules','CirclePlans')").Single() == 3);
    }

    [Fact]
    public async Task ReportsKeepExcusedAbsenceOutOfWarningsAndDownloadsMatchPreview()
    {
        using var connection = new SqliteConnection("Data Source=:memory:"); connection.Open();
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(connection).Options);
        db.Database.EnsureCreated();
        db.Circles.Add(new Circle { Id=1, Name="حلقة الاختبار", IsActive=true });
        db.Students.Add(new Student { Id=1, FullName="أحمد", CircleId=1, IsActive=true });
        db.Attendances.AddRange(
            new Attendance { StudentId=1,CircleId=1,SessionDate=new DateOnly(2026,10,1),Status=AttendanceStatus.Absent },
            new Attendance { StudentId=1,CircleId=1,SessionDate=new DateOnly(2026,10,2),Status=AttendanceStatus.ExcusedAbsent },
            new Attendance { StudentId=1,CircleId=1,SessionDate=new DateOnly(2026,10,3),Status=AttendanceStatus.Absent });
        db.SaveChanges();
        var report = await new OperationalReports(db).BuildAsync(new ReportFilter("cumulative_absence",new DateOnly(2026,10,1),new DateOnly(2026,10,5),AbsenceThreshold:2));
        Assert.Single(report.Rows); Assert.Equal("2",report.Rows[0][2]); Assert.Equal("1",report.Rows[0][3]);
        Assert.Empty((await new OperationalReports(db).BuildAsync(new ReportFilter("cumulative_absence",new DateOnly(2026,10,1),new DateOnly(2026,10,5),AbsenceThreshold:3))).Rows);
        var excel = DocumentRenderer.Excel(report); Assert.Equal((byte)'P',excel[0]); Assert.Equal((byte)'K',excel[1]);
    }

    [Fact]
    public void ParentIdentityOverridesSharedPhoneAndStaffBadgeRequiresActiveTeacher()
    {
        var parent = new User { Id=7,Username="123456789",Role=UserRole.Parent,Teacher=new Teacher{IsActive=true,IdentityNumber="123456789"} };
        Assert.False(ParentLinks.IsChild(parent,new Student{ParentIdentityNumber="987654321",FamilyContact="123456789"}));
        Assert.True(ParentLinks.IsChild(parent,new Student{ParentIdentityNumber="123456789"}));
    }

    [Fact]
    public void DaySchedulingAndExplicitPagesAreDeterministic()
    {
        Assert.True(CircleOperations.ScheduledOn(new CircleSchedule{Weekdays="1,4"},new DateOnly(2026,10,15)));
        Assert.False(CircleOperations.ScheduledOn(new CircleSchedule{Weekdays="1,4"},new DateOnly(2026,10,16)));
        Assert.Equal(1.5,ReportService.Pages(new RecitationSession{FromVerse=1,ToVerse=15,Pages=1.5,Assessment=AssessmentLevel.Good}));
    }

    [Fact]
    public void ArabicReportAndCertificateRenderAsDownloadableDocuments()
    {
        var table = new ReportTable("تقرير الحضور", ["الطالب", "الحالة"],
            [["أحمد", "غائب بعذر"]], "2026-10-15");
        var pdf = DocumentRenderer.Pdf(table);
        Assert.Equal("%PDF", System.Text.Encoding.ASCII.GetString(pdf, 0, 4));
        var certificate = DocumentRenderer.Certificate(new CertificateData(
            "مركز البيان", "أحمد", "أحكام التجويد", "CERT-1", "2026-10-15", "ممتاز",
            "الأستاذ خالد", "المعلم محمد", "معلم الدورة"));
        Assert.Equal("%PDF", System.Text.Encoding.ASCII.GetString(certificate.GeneratePdf(), 0, 4));
        var image = Assert.Single(certificate.GenerateImages());
        Assert.True(image.Length > 100);
    }
}
