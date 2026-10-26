using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using QuranCircles.Api.Controllers;
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
        db.Database.ExecuteSqlRaw("DROP TABLE \"QualityVisits\"");
        OperationsSchema.Ensure(db);
        OperationsSchema.Ensure(db);
        Assert.Equal(4, db.Database.SqlQueryRaw<int>("SELECT COUNT(*) AS Value FROM sqlite_master WHERE type='table' AND name IN ('CircleDays','CircleSchedules','CirclePlans','QualityVisits')").Single());
    }

    [Fact]
    public async Task CoursePlansUseCourseIdentityAndOldPlansReceiveTheNewColumn()
    {
        using var connection = new SqliteConnection("Data Source=:memory:"); connection.Open();
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(connection).Options);
        db.Database.EnsureCreated();
        db.Database.ExecuteSqlRaw("ALTER TABLE CirclePlans DROP COLUMN CourseId");
        OperationsSchema.Ensure(db);
        Assert.Equal(1, db.Database.SqlQueryRaw<int>("SELECT COUNT(*) AS Value FROM pragma_table_info('CirclePlans') WHERE name = 'CourseId'").Single());
        db.Courses.Add(new Course { Id = 7, Name = "دورة التجويد", IsActive = true });
        db.Teachers.AddRange(new Teacher { Id = 1, FullName = "مشرف الجودة", TaskRole = "مسؤول الجودة" },
            new Teacher { Id = 2, FullName = "معلم" });
        var admin = new User { Id = 1, Username = "admin", Role = UserRole.Admin };
        var quality = new User { Id = 2, Username = "quality", Role = UserRole.Teacher, TeacherId = 1 };
        var ordinary = new User { Id = 3, Username = "ordinary", Role = UserRole.Teacher, TeacherId = 2 };
        db.Users.AddRange(admin, quality, ordinary); await db.SaveChangesAsync();
        var context = new DefaultHttpContext(); context.Items["QuranCenter.VerifiedUser"] = admin;
        var controller = new OperationsController(db) { ControllerContext = new ControllerContext { HttpContext = context } };
        var today = CenterClock.Today;
        Assert.IsType<OkObjectResult>(await controller.SavePlan(new CirclePlan {
            CourseId = 7, Track = "Course", Title = "دروس التجويد", Unit = "درس",
            StartsOn = today, EndsOn = today.AddDays(30), Target = 12 }));
        var saved = await db.CirclePlans.SingleAsync();
        Assert.Equal(7, saved.CourseId);
        Assert.Equal(0, saved.CircleId);
        context.Items["QuranCenter.VerifiedUser"] = ordinary;
        Assert.IsType<ForbidResult>(await controller.SavePlan(new CirclePlan {
            CourseId = 7, Track = "Course", Title = "خطة أخرى", Unit = "درس",
            StartsOn = today, EndsOn = today.AddDays(30), Target = 8 }));
        context.Items["QuranCenter.VerifiedUser"] = quality;
        Assert.IsType<OkObjectResult>(await controller.SavePlan(new CirclePlan {
            CourseId = 7, Track = "Course", Title = "خطة الجودة", Unit = "درس",
            StartsOn = today, EndsOn = today.AddDays(30), Target = 8 }));
    }

    [Fact]
    public async Task ExistingCenterCanLoadQualityAfterMissingVisitsTableIsUpgraded()
    {
        using var connection = new SqliteConnection("Data Source=:memory:"); connection.Open();
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(connection).Options);
        db.Database.EnsureCreated();
        db.Circles.AddRange(new Circle { Id = 1, Name = "حلقة البيان", IsActive = true },
            new Circle { Id = 2, Name = "حلقة دون رصد", IsActive = true });
        db.Students.Add(new Student { Id = 1, FullName = "أحمد", CircleId = 1, IsActive = true });
        db.Sessions.Add(new RecitationSession { StudentId = 1, RecordedCircleId = 1, SessionDate = CenterClock.Today,
            SurahName = "الفاتحة", FromVerse = 1, ToVerse = 7, Assessment = AssessmentLevel.Excellent });
        db.Attendances.Add(new Attendance { StudentId = 1, CircleId = 1, SessionDate = CenterClock.Today, Status = AttendanceStatus.Present });
        await db.SaveChangesAsync();
        db.Database.ExecuteSqlRaw("DROP TABLE \"QualityVisits\"");
        OperationsSchema.Ensure(db);
        OperationsSchema.Ensure(db);
        db.QualityVisits.Add(new QualityVisit { CircleId = 1, SupervisorName = "المشرف", VisitDate = CenterClock.Today });
        await db.SaveChangesAsync();

        var controller = new QualityController(db, NullLogger<QualityController>.Instance) {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
        };
        var result = Assert.IsType<OkObjectResult>(await controller.GetOverview());
        var json = System.Text.Json.JsonSerializer.SerializeToElement(result.Value);
        Assert.Equal(1, json.GetProperty("Stats").GetProperty("TotalStudents").GetInt32());
        Assert.Equal(1, json.GetProperty("Stats").GetProperty("TotalSessions").GetInt32());
        Assert.Equal(100, json.GetProperty("Stats").GetProperty("AvgAttendanceRate").GetInt32());
        Assert.Single(await db.QualityVisits.ToListAsync());
        Assert.Equal("أحمد", (await db.Students.SingleAsync()).FullName);
        var dashboard = System.Text.Json.JsonSerializer.SerializeToElement(
            await new ReportService(db).GetExecutiveDashboardAsync(CenterClock.Today, CenterClock.Today));
        var rankedCircles = dashboard.GetProperty("quality").GetProperty("lowestCircles");
        Assert.Equal(1, rankedCircles.GetArrayLength());
        Assert.Equal("حلقة البيان", rankedCircles[0].GetProperty("CircleName").GetString());
    }

    [Fact]
    public void CertificateThumbnailsAreSmallerAndKeepTheFullDocumentAvailable()
    {
        var data = new CertificateData("مركز البيان", "أحمد", "إتمام جزء عم", "CERT-2", "2026-10-15", "ممتاز", "أمير المركز");
        var thumbnail = CertificateArtifacts.Render(data, "png", true);
        var preview = CertificateArtifacts.Render(data, "png");
        var smallWidth = System.Buffers.Binary.BinaryPrimitives.ReadInt32BigEndian(thumbnail.AsSpan(16, 4));
        var fullWidth = System.Buffers.Binary.BinaryPrimitives.ReadInt32BigEndian(preview.AsSpan(16, 4));
        Assert.True(smallWidth < fullWidth);
        Assert.True(thumbnail.Length < preview.Length);
        Assert.Equal("%PDF", System.Text.Encoding.ASCII.GetString(CertificateArtifacts.Render(data, "pdf"), 0, 4));
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
