using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using System.Text.Json;
using Xunit;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using QuranCircles.Api.Controllers;

namespace QuranCircles.Api.Tests;

public class ParentPortalAndPermissionsTests
{
    private static AppDbContext Open(SqliteConnection c){c.Open();var db=new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(c).Options);db.Database.EnsureCreated();return db;}
    [Fact]
    public async Task AStudentCircleAnnouncementReachesOnlyTheAssignedAudience()
    {
        using var c=new SqliteConnection("Data Source=:memory:");using var db=Open(c);
        db.Teachers.AddRange(new Teacher {Id=1,FullName="معلم الحلقة"},new Teacher {Id=2,FullName="معلم الدورة"},new Teacher {Id=3,FullName="معلم دورة الزميل"});
        db.Circles.AddRange(new Circle {Id=1,Name="الأولى",TeacherId=1},new Circle {Id=2,Name="الثانية"});
        db.Courses.AddRange(new Course {Id=1,Name="التجويد",TeacherId=2},new Course {Id=2,Name="دورة الزميل",TeacherId=3});
        db.Students.AddRange(new Student {Id=1,FullName="المرسل",CircleId=1,ParentId=5},new Student {Id=2,FullName="زميل",CircleId=1},new Student {Id=3,FullName="طالب آخر",CircleId=2});
        db.CourseEnrollments.Add(new CourseEnrollment {StudentId=1,CourseId=1});
        db.CourseEnrollments.Add(new CourseEnrollment {StudentId=2,CourseId=2});
        var sender=new User {Id=1,Username="sender",FullName="المرسل",Role=UserRole.Student,StudentId=1};
        var peer=new User {Id=2,Username="peer",FullName="زميل",Role=UserRole.Student,StudentId=2};
        var outsider=new User {Id=3,Username="outsider",FullName="طالب آخر",Role=UserRole.Student,StudentId=3};
        var circleTeacher=new User {Id=4,Username="circle",FullName="معلم الحلقة",Role=UserRole.Teacher,TeacherId=1};
        var parent=new User {Id=5,Username="parent",FullName="ولي الأمر",Role=UserRole.Parent};
        var courseTeacher=new User {Id=6,Username="course",FullName="معلم الدورة",Role=UserRole.Teacher,TeacherId=2};
        var admin=new User {Id=7,Username="admin",FullName="المدير",Role=UserRole.Admin};
        var peerCourseTeacher=new User {Id=8,Username="peerCourse",FullName="معلم دورة الزميل",Role=UserRole.Teacher,TeacherId=3};
        db.Users.AddRange(sender,peer,outsider,circleTeacher,parent,courseTeacher,admin,peerCourseTeacher);await db.SaveChangesAsync();
        var context=new DefaultHttpContext();context.Items["QuranCenter.VerifiedUser"]=sender;
        var service=new AnnouncementService(db);
        var controller=new AnnouncementsController(service,db){ControllerContext=new ControllerContext {HttpContext=context}};
        Assert.IsType<BadRequestObjectResult>(await controller.Create(new("خارج الحلقة","رسالة",AnnouncementTarget.Circle,2)));
        Assert.IsType<OkObjectResult>(await controller.Create(new("من الطالب","رسالة",AnnouncementTarget.Circle,1)));
        Assert.Single(await service.GetMyAnnouncementsAsync(peer.Id));
        Assert.Single(await service.GetMyAnnouncementsAsync(circleTeacher.Id));
        Assert.Single(await service.GetMyAnnouncementsAsync(courseTeacher.Id));
        Assert.Empty(await service.GetMyAnnouncementsAsync(peerCourseTeacher.Id));
        Assert.Single(await service.GetMyAnnouncementsAsync(admin.Id));
        Assert.Empty(await service.GetMyAnnouncementsAsync(outsider.Id));
        Assert.Empty(await service.GetMyAnnouncementsAsync(parent.Id));
    }
    [Fact]
    public async Task DuplicateExamNominationsAndDirectCourseGradesAreRejected()
    {
        using var c=new SqliteConnection("Data Source=:memory:");using var db=Open(c);
        db.Teachers.Add(new Teacher {Id=1,FullName="معلم الدورة"});
        db.Courses.Add(new Course {Id=1,Name="التجويد",TeacherId=1});
        db.Students.Add(new Student {Id=1,FullName="الطالب"});
        db.CourseEnrollments.Add(new CourseEnrollment {Id=1,StudentId=1,CourseId=1});
        var user=new User {Id=1,Username="teacher",Role=UserRole.Teacher,TeacherId=1};
        var admin=new User {Id=2,Username="admin",Role=UserRole.Admin};
        db.Users.AddRange(user,admin);
        await db.SaveChangesAsync();
        var context=new DefaultHttpContext();context.Items["QuranCenter.VerifiedUser"]=user;
        var exams=new ExamsController(db){ControllerContext=new ControllerContext {HttpContext=context}};
        Assert.IsType<OkObjectResult>(await exams.Nominate(new() {StudentId=1,NominationType="Course",CourseId=1}));
        Assert.IsType<ConflictObjectResult>(await exams.Nominate(new() {StudentId=1,NominationType="Course",CourseId=1}));
        var courses=new CoursesController(db){ControllerContext=new ControllerContext {HttpContext=context}};
        Assert.IsType<BadRequestObjectResult>(courses.RecordGrade(new(1,95)));
        var enrollment=await db.CourseEnrollments.SingleAsync();
        Assert.Null(enrollment.Grade);Assert.Null(enrollment.CertificateCode);
        enrollment.Grade=95;enrollment.Status="Passed";enrollment.CertificateCode="LEGACY";await db.SaveChangesAsync();
        var rows=Assert.IsType<OkObjectResult>(await courses.GetEnrollments(1));
        var row=Assert.Single(JsonSerializer.SerializeToElement(rows.Value).EnumerateArray());
        Assert.Equal(JsonValueKind.Null,row.GetProperty("Grade").ValueKind);
        Assert.Equal(JsonValueKind.Null,row.GetProperty("CertificateCode").ValueKind);
        Assert.Equal("Enrolled",row.GetProperty("Status").GetString());
        context.Items["QuranCenter.VerifiedUser"]=admin;
        var report=Assert.IsType<OkObjectResult>(await courses.GetComprehensiveReport());
        var course=Assert.Single(JsonSerializer.SerializeToElement(report.Value).GetProperty("Courses").EnumerateArray());
        var reportStudent=Assert.Single(course.GetProperty("Students").EnumerateArray());
        Assert.Equal(JsonValueKind.Null,reportStudent.GetProperty("Grade").ValueKind);
        Assert.Equal("-",reportStudent.GetProperty("CertificateCode").GetString());
        Assert.Equal("قيد الدراسة",reportStudent.GetProperty("StatusArabic").GetString());
    }
    [Theory]
    [InlineData("معلم دورات","courses")]
    [InlineData("معلم دورة","courses")]
    [InlineData("مشرف المساقات الشرعية","courses")]
    [InlineData("معلم الدَّورات","courses")]
    [InlineData("محفّظ حلقة","circles")]
    [InlineData("مشرف اختبارات","exams")]
    public void TaskSpellingsResolveToTheSamePermission(string text,string permission)
    {
        Assert.Contains(permission,TeacherPermissions.FromTasks(text));
        if(permission=="courses")Assert.DoesNotContain("circles",TeacherPermissions.FromTasks(text));
    }
    [Fact]
    public async Task UnlinkedTeacherAccountIsResolvedOnlyByAUniqueIdentityAndNeverByName()
    {
        using var c=new SqliteConnection("Data Source=:memory:");using var db=Open(c);
        db.Teachers.Add(new Teacher {Id=1,FullName="أحمد",IdentityNumber="123456789",TaskRole="معلم دورات"});
        var user=new User {Id=1,Username="123456789",FullName="اسم آخر",Role=UserRole.Teacher};
        var other=new User {Id=2,Username="other",FullName="أحمد",Role=UserRole.Teacher};
        db.Users.AddRange(user,other);await db.SaveChangesAsync();
        await TeacherPermissions.ResolveLinkAsync(db,user);await TeacherPermissions.ResolveLinkAsync(db,other);
        Assert.Equal(1,user.TeacherId);Assert.Null(other.TeacherId);Assert.Equal(UserRole.Teacher,user.Role);
        Assert.Equal(["courses"],TeacherPermissions.For(user.Teacher));
        user.Teacher!.IsActive=false;Assert.Empty(TeacherPermissions.For(user.Teacher));
    }
    [Fact]
    public async Task ActualCourseAndAssistantAssignmentsGrantScopedTeacherToolsWithoutJobText()
    {
        using var c=new SqliteConnection("Data Source=:memory:");using var db=Open(c);
        var courseTeacher=new Teacher {Id=1,FullName="معلم الدورة",TaskRole="غير مكلف"};
        var assistant=new Teacher {Id=2,FullName="مساعد الحلقة",TaskRole="غير مكلف"};
        var otherTeacher=new Teacher {Id=3,FullName="معلم آخر",TaskRole="غير مكلف"};
        db.Teachers.AddRange(courseTeacher,assistant,otherTeacher);
        var courseUser=new User {Id=1,Username="course",FullName="معلم الدورة",Role=UserRole.Teacher,TeacherId=1};
        var assistantUser=new User {Id=2,Username="assistant",FullName="مساعد الحلقة",Role=UserRole.Teacher,TeacherId=2};
        db.Users.AddRange(courseUser,assistantUser);
        db.Circles.Add(new Circle {Id=1,Name="حلقة البيان",AssistantTeacherId=2});
        db.Courses.Add(new Course {Id=1,Name="التجويد",TeacherId=1});
        db.Courses.Add(new Course {Id=2,Name="دورة أخرى",TeacherId=3});
        db.Students.AddRange(new Student {Id=1,FullName="طالب الحلقة",CircleId=1},new Student {Id=2,FullName="طالب الدورة"},new Student {Id=3,FullName="طالب آخر"});
        db.CourseEnrollments.Add(new CourseEnrollment {CourseId=1,StudentId=2});
        db.CourseEnrollments.Add(new CourseEnrollment {CourseId=2,StudentId=3});
        await db.SaveChangesAsync();

        Assert.Equal(["courses","exams"],(await TeacherPermissions.EffectiveForAsync(db,courseUser)).Order().ToArray());
        Assert.Equal(["circles","exams"],(await TeacherPermissions.EffectiveForAsync(db,assistantUser)).Order().ToArray());
        var context=new DefaultHttpContext();context.Items["QuranCenter.VerifiedUser"]=assistantUser;
        var exams=new ExamsController(db){ControllerContext=new ControllerContext {HttpContext=context}};
        Assert.IsType<OkObjectResult>(await exams.Nominate(new() {StudentId=1,NominationType="Quran",JuzStart=1,JuzEnd=1}));
        Assert.IsType<BadRequestObjectResult>(await exams.Nominate(new() {StudentId=3,NominationType="Quran",JuzStart=1,JuzEnd=1}));
        context.Items["QuranCenter.VerifiedUser"]=courseUser;
        Assert.IsType<OkObjectResult>(await exams.Nominate(new() {StudentId=2,NominationType="Course",CourseId=1}));
        Assert.IsType<BadRequestObjectResult>(await exams.Nominate(new() {StudentId=3,NominationType="Course",CourseId=1}));
        var list=Assert.IsType<OkObjectResult>(await exams.GetNominations());
        Assert.Single(Assert.IsAssignableFrom<System.Collections.IEnumerable>(list.Value).Cast<object>());
        var courses=new CoursesController(db){ControllerContext=new ControllerContext {HttpContext=context}};
        Assert.IsType<ForbidResult>(await courses.GetEnrollments(2));
        db.Courses.Single(x=>x.Id==1).TeacherId=null;
        await db.SaveChangesAsync();
        Assert.Empty(await TeacherPermissions.EffectiveForAsync(db,courseUser));
    }
    [Fact]
    public async Task PortfolioSourcesRespectCircleCourseAndParentLinks()
    {
        using var c=new SqliteConnection("Data Source=:memory:");using var db=Open(c);
        db.Teachers.AddRange(new Teacher {Id=1,FullName="مساعد الحلقة"},
            new Teacher {Id=2,FullName="معلم الدورة"},new Teacher {Id=3,FullName="معلم آخر"});
        var assistant=new User {Id=11,Username="assistant",Role=UserRole.Teacher,TeacherId=1};
        var courseTeacher=new User {Id=12,Username="course",Role=UserRole.Teacher,TeacherId=2};
        var parent=new User {Id=13,Username="parent",Role=UserRole.Parent};
        var admin=new User {Id=14,Username="admin",Role=UserRole.Admin};
        var supervisor=new User {Id=15,Username="supervisor",Role=UserRole.ExamSupervisor};
        db.Users.AddRange(assistant,courseTeacher,parent,admin,supervisor);
        db.Circles.Add(new Circle {Id=1,Name="حلقة",AssistantTeacherId=1});
        db.Courses.AddRange(new Course {Id=1,Name="دورة المعلم",TeacherId=2,ExamSupervisorId=15},
            new Course {Id=2,Name="دورة أخرى",TeacherId=3});
        db.Students.AddRange(new Student {Id=1,FullName="طالب الحلقة",CircleId=1},
            new Student {Id=2,FullName="طالب الدورة"},new Student {Id=3,FullName="طالب آخر"},
            new Student {Id=4,FullName="ابن ولي الأمر",ParentId=13},
            new Student {Id=5,FullName="ابن المعلم",ParentId=11});
        foreach(var (id,studentId,courseId) in new[]{(1,1,2),(2,2,1),(3,3,2),(4,4,2),(5,5,2)})
        {
            db.CourseEnrollments.Add(new CourseEnrollment {Id=id,StudentId=studentId,CourseId=courseId,Status="Passed",Grade=90,CertificateCode=$"C-{id}"});
            db.ExamNominations.Add(new ExamNomination {Id=id,StudentId=studentId,NominationType="Course",CourseId=courseId,Status="Completed"});
        }
        await db.SaveChangesAsync();

        async Task<int[]> CourseStudentIds(User user)
        {
            var context=new DefaultHttpContext();context.Items["QuranCenter.VerifiedUser"]=user;
            var result=Assert.IsType<OkObjectResult>(await new CoursesController(db){ControllerContext=new ControllerContext{HttpContext=context}}.GetMyCourses());
            return JsonSerializer.SerializeToElement(result.Value).EnumerateArray()
                .Select(x=>x.GetProperty("StudentId").GetInt32()).Order().ToArray();
        }
        async Task<int[]> ExamStudentIds(User user)
        {
            var context=new DefaultHttpContext();context.Items["QuranCenter.VerifiedUser"]=user;
            var result=Assert.IsType<OkObjectResult>(await new ExamsController(db){ControllerContext=new ControllerContext{HttpContext=context}}.GetNominations());
            return JsonSerializer.SerializeToElement(result.Value).EnumerateArray()
                .Select(x=>x.GetProperty("StudentId").GetInt32()).Order().ToArray();
        }
        Assert.Equal(new[]{1,5},await CourseStudentIds(assistant));
        Assert.Equal(new[]{2},await CourseStudentIds(courseTeacher));
        Assert.Equal(new[]{4},await CourseStudentIds(parent));
        Assert.Equal(new[]{2},await CourseStudentIds(supervisor));
        Assert.Equal(new[]{1,2,3,4,5},await CourseStudentIds(admin));
        Assert.Equal(new[]{1,5},await ExamStudentIds(assistant));
        Assert.Equal(new[]{2},await ExamStudentIds(courseTeacher));
        Assert.Equal(new[]{4},await ExamStudentIds(parent));
        Assert.Equal(new[]{1,2,3,4,5},await ExamStudentIds(supervisor));
        Assert.Equal(new[]{1,2,3,4,5},await ExamStudentIds(admin));
    }
    [Fact]
    public async Task ParentChangeRequestsAreLimitedToTheirChildrenAndRecordTheVerifiedIdentity()
    {
        using var c=new SqliteConnection("Data Source=:memory:");using var db=Open(c);
        var parent=new User {Id=1,Username="parent",FullName="ولي الأمر",Role=UserRole.Parent};
        db.Users.AddRange(parent,new User {Id=2,Username="other",Role=UserRole.Parent});
        db.Students.AddRange(new Student {Id=1,FullName="ابني",ParentId=1},new Student {Id=2,FullName="طالب آخر",ParentId=2});await db.SaveChangesAsync();
        var context=new DefaultHttpContext();context.Items["QuranCenter.VerifiedUser"]=parent;
        var controller=new ProfileUpdateRequestsController(db){ControllerContext=new ControllerContext {HttpContext=context}};
        var changes=new Dictionary<string,string>{{"familyContact","0591234567"}};
        Assert.IsType<ForbidResult>(await controller.Submit(new(2,"Developer","اسم مزور",changes)));
        Assert.IsType<OkObjectResult>(await controller.Submit(new(1,"Developer","اسم مزور",changes)));
        var stored=await db.ProfileUpdateRequests.SingleAsync();Assert.Equal("Parent",stored.RequestedByRole);Assert.Equal(parent.FullName,stored.RequestedByName);
    }

    [Fact]
    public async Task ParentPortalUsesTheSamePeriodAndSeparatesExcusedAbsenceWithoutLeakingOtherChildren()
    {
        using var c=new SqliteConnection("Data Source=:memory:");using var db=Open(c);
        db.Teachers.Add(new Teacher {Id=1,FullName="المعلم",IdentityNumber="123456789",WhatsappNumber="+970599123456"});
        var parent=new User {Id=7,Username="123456789",Role=UserRole.Teacher,TeacherId=1};
        db.Users.AddRange(parent,new User {Id=8,Username="other",Role=UserRole.Parent});
        db.Circles.Add(new Circle {Id=1,Name="البيان",TeacherId=1});
        db.Students.AddRange(new Student {Id=10,FullName="أحمد",ParentId=7,CircleId=1,CompletedAjzaa="1,2,2,99",TargetAjzaaCount=5},
            new Student {Id=11,FullName="محمد",ParentIdentityNumber="123456789",CircleId=1},
            new Student {Id=12,FullName="ابن حساب آخر",ParentId=8,ParentIdentityNumber="123456789",CircleId=1});
        var from=new DateOnly(2026,10,1);var to=new DateOnly(2026,10,15);
        db.Attendances.AddRange(new Attendance {StudentId=10,CircleId=1,SessionDate=from,Status=AttendanceStatus.Present},
            new Attendance {StudentId=10,CircleId=1,SessionDate=from.AddDays(1),Status=AttendanceStatus.Absent},
            new Attendance {StudentId=10,CircleId=1,SessionDate=from.AddDays(2),Status=AttendanceStatus.ExcusedAbsent});
        db.Sessions.AddRange(new RecitationSession {StudentId=10,SessionDate=from,SurahName="النبأ",Pages=1.5,RecitationType=RecitationType.Memorization,Assessment=AssessmentLevel.Good},
            new RecitationSession {StudentId=10,SessionDate=from.AddDays(-1),SurahName="الملك",Pages=5,Assessment=AssessmentLevel.Good});
        db.Courses.Add(new Course {Id=5,Name="التجويد",TeacherId=1});
        db.CourseEnrollments.Add(new CourseEnrollment {CourseId=5,StudentId=10,Grade=95,Status="Passed"});
        await db.SaveChangesAsync();
        var json=JsonSerializer.SerializeToElement(await new ParentPortalService(db).BuildAsync(parent,from,to));
        Assert.Equal(2,json.GetProperty("summary").GetProperty("childrenCount").GetInt32());
        Assert.Equal(1,json.GetProperty("summary").GetProperty("totalSessions").GetInt32());
        var children=json.GetProperty("children");Assert.Equal(2,children.GetArrayLength());
        var child=children[0];Assert.Equal(10,child.GetProperty("studentId").GetInt32());
        Assert.Equal(1,child.GetProperty("absentCount").GetInt32());Assert.Equal(1,child.GetProperty("excusedAbsentCount").GetInt32());
        Assert.Equal(2,child.GetProperty("completedAjzaaCount").GetInt32());Assert.Equal(1.5,child.GetProperty("newPages").GetDouble());
        Assert.Single(child.GetProperty("courses").EnumerateArray());Assert.Equal(JsonValueKind.Null,children[1].GetProperty("attendanceRate").ValueKind);
        Assert.DoesNotContain("ابن حساب آخر",json.ToString());
    }
}
