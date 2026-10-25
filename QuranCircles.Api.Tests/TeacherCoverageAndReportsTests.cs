using Microsoft.AspNetCore.Http;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using Xunit;

namespace QuranCircles.Api.Tests;

public class TeacherCoverageAndReportsTests
{
    [Fact]
    public async Task CmsDailyRecordingRuleBlocksTeacherBackfillButNotAdministrator()
    {
        using var connection = new SqliteConnection("Data Source=:memory:");
        using var db = Open(connection);
        db.SystemSettings.Add(new SystemSettings { EnforceDailyAttendanceRecording = true });
        db.Teachers.Add(new Teacher { Id = 1, FullName = "معلم", IsActive = true });
        db.Users.AddRange(
            new User { Id = 1, Username = "teacher", Role = UserRole.Teacher, TeacherId = 1 },
            new User { Id = 2, Username = "admin", Role = UserRole.Admin });
        db.Circles.Add(new Circle { Id = 1, Name = "حلقة", TeacherId = 1, IsActive = true });
        await db.SaveChangesAsync();
        var context = new DefaultHttpContext();
        context.Items["QuranCenter.VerifiedUser"] = await db.Users.Include(u => u.Teacher).SingleAsync(u => u.Id == 1);
        var operation = new CircleOperations(db);
        Assert.True(await operation.CanRecordAsync(context, 1, CenterClock.Today));
        Assert.False(await operation.CanRecordAsync(context, 1, CenterClock.Today.AddDays(-1)));
        context.Items["QuranCenter.VerifiedUser"] = await db.Users.SingleAsync(u => u.Id == 2);
        Assert.True(await operation.CanRecordAsync(context, 1, CenterClock.Today.AddDays(-1)));
    }

    [Fact]
    public void TeacherStudentViewCanHideParentContactWithoutHidingStudentPhone()
    {
        var student = new Student { FullName = "طالب", FamilyContact = "0590000000", WhatsappNumber = "0590000001", StudentMobile = "0590000002" };
        var hidden = System.Text.Json.JsonSerializer.SerializeToElement(StudentService.MapStudentToFullObject(student, hideParentPhone: true));
        Assert.Equal(System.Text.Json.JsonValueKind.Null, hidden.GetProperty("FamilyContact").ValueKind);
        Assert.Equal(System.Text.Json.JsonValueKind.Null, hidden.GetProperty("WhatsappNumber").ValueKind);
        Assert.Equal("0590000002", hidden.GetProperty("StudentMobile").GetString());
    }

    private static AppDbContext Open(SqliteConnection connection)
    {
        connection.Open();
        var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(connection).Options);
        db.Database.EnsureCreated();
        return db;
    }

    [Fact]
    public async Task MissingSessionDoesNotBecomeAbsenceWithoutAnExplicitRecord()
    {
        using var connection = new SqliteConnection("Data Source=:memory:");
        using var db = Open(connection);
        db.Circles.AddRange(new Circle {Id=1,Name="مجدولة"},new Circle {Id=2,Name="دون موعد"});
        db.CircleSchedules.Add(new CircleSchedule {CircleId=1,Weekdays="4",StartTime="16:00",DurationMinutes=60});
        await db.SaveChangesAsync();
        var service = new TeacherAttendanceService(db);
        var date = new DateOnly(2026,10,15);
        var late = await service.BuildAsync(date,date,localNow:new DateTime(2026,10,15,16,20,0));
        Assert.Equal("LatePending",late.Single(r=>r.CircleId==1).Status);
        Assert.Equal(20,late.Single(r=>r.CircleId==1).LateMinutes);
        var finished = await service.BuildAsync(date,date,localNow:new DateTime(2026,10,15,17,0,0));
        Assert.Equal("LatePending",finished.Single(r=>r.CircleId==1).Status);
        var nextDay = await service.BuildAsync(date,date,localNow:new DateTime(2026,10,16,8,0,0));
        Assert.Equal("NotAbsent",nextDay.Single(r=>r.CircleId==1).Status);
        Assert.False(nextDay.Single(r=>r.CircleId==1).IsAutomatic);
        Assert.Equal("Unscheduled",finished.Single(r=>r.CircleId==2).Status);
        Assert.False(finished.Single(r=>r.CircleId==2).IsAutomatic);
    }

    [Fact]
    public async Task CoverageGrantsOnlyTheSelectedAccountAndKeepsTheOriginalTeacherAbsent()
    {
        using var connection = new SqliteConnection("Data Source=:memory:");
        using var db = Open(connection);
        db.Teachers.AddRange(new Teacher {Id=1,FullName="الأصلي",TaskRole="محفّظ"},new Teacher {Id=2,FullName="البديل",TaskRole="الجودة"});
        var original = new User {Id=1,Username="original",Role=UserRole.Teacher,TeacherId=1,FullName="الأصلي"};
        var substitute = new User {Id=2,Username="substitute",Role=UserRole.Teacher,TeacherId=2,FullName="البديل"};
        db.Users.AddRange(original,substitute);
        db.Circles.Add(new Circle {Id=1,Name="حلقة التغطية",TeacherId=1});
        db.Students.Add(new Student {Id=1,FullName="أحمد",CircleId=1});
        await db.SaveChangesAsync();
        var service = new TeacherAttendanceService(db);
        await Assert.ThrowsAsync<ArgumentException>(()=>service.AssignAsync(1,CenterClock.Today,1,"إجازة",1,"الإدارة"));
        await service.AssignAsync(1,CenterClock.Today,2,"إجازة",1,"الإدارة");
        var context = new DefaultHttpContext();
        context.Items["QuranCenter.VerifiedUser"]=original;
        Assert.False(await new CircleOperations(db).CanRecordAsync(context,1,CenterClock.Today));
        context.Items["QuranCenter.VerifiedUser"]=substitute;
        Assert.True(await new CircleOperations(db).CanRecordAsync(context,1,CenterClock.Today));
        Assert.Single(await new CircleService(db).GetAllForTeacherAsync(2,2));
        Assert.Single(await new StudentService(db,new PasswordHasher()).GetStudentsForTeacherAsync(2,null,true,2));
        await new CircleOperations(db).StartAsync(1,2,CenterClock.Today);
        var row=Assert.Single(await service.BuildAsync(CenterClock.Today,CenterClock.Today));
        Assert.Equal("Absent",row.Status);
        Assert.Equal("البديل",row.SubstituteName);
        Assert.False(row.IsAutomatic);
        Assert.NotNull(row.OpenedAt);
        await service.AssignAsync(1,CenterClock.Today,null,"انتهت التغطية",1,"الإدارة");
        Assert.False(await new CircleOperations(db).CanRecordAsync(context,1,CenterClock.Today));
    }

    [Fact]
    public async Task StudentProfileUsesRealCertificateIdsAndDoesNotPassFailedExams()
    {
        using var connection = new SqliteConnection("Data Source=:memory:");
        using var db = Open(connection);
        db.SystemSettings.Add(new SystemSettings {PassingScoreThreshold=70});
        db.Students.Add(new Student {Id=1,FullName="أحمد",CompletedAjzaa="1,1,2",TargetAjzaaCount=5});
        db.Courses.Add(new Course {Id=1,Name="التجويد"});
        db.CourseEnrollments.AddRange(new CourseEnrollment {Id=42,StudentId=1,CourseId=1,Status="Passed",Grade=95,CertificateCode="CERT-42"},
            new CourseEnrollment {Id=43,StudentId=1,CourseId=1,Status="Passed",Grade=30,CertificateCode="CERT-43"});
        db.ExamNominations.Add(new ExamNomination {Id=1,StudentId=1,Status="Completed",JuzStart=3,JuzEnd=3,Result=new ExamResult {Grade=40}});
        db.ExamNominations.Add(new ExamNomination {Id=2,StudentId=1,NominationType="Course",CourseId=1,Status="Completed",Result=new ExamResult {Grade=95}});
        await db.SaveChangesAsync();
        var (profile,error)=await new StudentService(db,new PasswordHasher()).GetStudentProgressByIdAsync(1);
        Assert.Null(error);
        var json=System.Text.Json.JsonSerializer.SerializeToElement(profile);
        var certificate=Assert.Single(json.GetProperty("CompletedExams").EnumerateArray());
        Assert.Equal("course",certificate.GetProperty("CertificateKind").GetString());
        Assert.Equal(42,certificate.GetProperty("CertificateId").GetInt32());
        Assert.Equal("Completed",json.GetProperty("JuzStatus").GetProperty("1").GetString());
        Assert.Equal("NotStarted",json.GetProperty("JuzStatus").GetProperty("3").GetString());
    }

    [Fact]
    public async Task ReportScopeIsExplicitAndAcademicReportListsActualEnrollments()
    {
        using var connection = new SqliteConnection("Data Source=:memory:");
        using var db = Open(connection);
        db.Circles.Add(new Circle {Id=1,Name="الحلقة"});
        db.Students.AddRange(new Student {Id=1,FullName="أحمد",CircleId=1},new Student {Id=2,FullName="محمد",CircleId=1});
        db.Courses.AddRange(new Course {Id=1,Name="التجويد"},new Course {Id=2,Name="العقيدة"});
        db.CourseEnrollments.AddRange(new CourseEnrollment {StudentId=1,CourseId=1,Status="Passed",Grade=95},new CourseEnrollment {StudentId=2,CourseId=2});
        await db.SaveChangesAsync();
        var service=new OperationalReports(db);
        Assert.Equal(2,(await service.BuildAsync(new ReportFilter())).Rows.Count);
        Assert.Single((await service.BuildAsync(new ReportFilter(StudentIds:[1]))).Rows);
        Assert.Empty((await service.BuildAsync(new ReportFilter(StudentIds:[]))).Rows);
        var report=await service.BuildAsync(new ReportFilter("course_roster",CourseId:1));
        var row=Assert.Single(report.Rows);
        Assert.Contains("التجويد",row);Assert.Contains("أحمد",row);Assert.Contains("95",row);
        var profile=await service.BuildAsync(new ReportFilter("student_profile",StudentIds:[1]));
        Assert.Contains(profile.Rows,r=>r.Contains("أحمد"));
        Assert.Equal(30,profile.Rows.Count(r=>r[0]=="خريطة الحفظ"));
    }
}
