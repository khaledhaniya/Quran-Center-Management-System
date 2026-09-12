using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/quality")]
public class QualityController : ControllerBase
{
    private readonly AppDbContext _db;

    public QualityController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet("overview")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.ExamSupervisor)]
    public async Task<IActionResult> GetOverview()
    {
        try
        {
            // 1. Fetch Circles with Teachers & Students
            var circles = await _db.Circles
                .Include(c => c.Teacher)
                .Include(c => c.Students)
                .AsNoTracking()
                .ToListAsync();

            // 2. Fetch all Attendances
            var attendances = await _db.Attendances
                .AsNoTracking()
                .ToListAsync();

            // 3. Fetch all Recitation Sessions
            var sessions = await _db.Sessions
                .AsNoTracking()
                .ToListAsync();

            // 4. Fetch all Courses with Enrollments & Course Attendance
            var courses = await _db.Courses
                .Include(c => c.Teacher)
                .Include(c => c.Enrollments)
                    .ThenInclude(e => e.Student)
                .AsNoTracking()
                .ToListAsync();

            var courseAttendances = await _db.CourseAttendances
                .AsNoTracking()
                .ToListAsync();

            // Aggregate circle data
            var circleDataList = new List<object>();

            int allPresentCount = 0;
            int allTotalAttCount = 0;
            int allExcellenceCount = 0;
            int allTotalRecitations = sessions.Count;
            int allMemorizationCount = sessions.Count(s => s.RecitationType == RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
            int allRevisionCount = sessions.Count(s => s.RecitationType == RecitationType.Revision && s.Assessment != AssessmentLevel.DidNotRecite);
            int allDidNotReciteCount = sessions.Count(s => s.Assessment == AssessmentLevel.DidNotRecite);
            int allTotalVerses = sessions.Where(s => s.Assessment != AssessmentLevel.DidNotRecite).Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));

            foreach (var c in circles)
            {
                var circleStudents = c.Students.Where(s => s.IsActive).ToList();
                var studentIds = circleStudents.Select(s => s.Id).ToHashSet();

                var cAttendances = attendances.Where(a => a.CircleId == c.Id || studentIds.Contains(a.StudentId)).ToList();
                var cSessions = sessions.Where(s => studentIds.Contains(s.StudentId)).ToList();

                int presentCount = cAttendances.Count(a => a.Status == AttendanceStatus.Present);
                int absentCount = cAttendances.Count(a => a.Status == AttendanceStatus.Absent);
                int lateCount = cAttendances.Count(a => a.Status == AttendanceStatus.Late);
                int totalAtt = cAttendances.Count;

                allPresentCount += presentCount;
                allTotalAttCount += totalAtt;

                int cExcellence = cSessions.Count(s => s.Assessment == AssessmentLevel.Excellent);
                allExcellenceCount += cExcellence;

                int attendanceRate = totalAtt > 0 ? (int)Math.Round((double)presentCount / totalAtt * 100) : 100;
                int memSessions = cSessions.Count(s => s.RecitationType == RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
                int revSessions = cSessions.Count(s => s.RecitationType == RecitationType.Revision && s.Assessment != AssessmentLevel.DidNotRecite);
                int didNotReciteSessions = cSessions.Count(s => s.Assessment == AssessmentLevel.DidNotRecite);
                int totalVerses = cSessions.Where(s => s.Assessment != AssessmentLevel.DidNotRecite).Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));

                string qualityScore = attendanceRate >= 90 ? "ممتاز ⭐⭐⭐" : (attendanceRate >= 80 ? "جيد جداً ⭐⭐" : "جيد ⭐");

                // Breakdown of students in this circle
                var studentBreakdown = circleStudents.Select(st =>
                {
                    var stAtt = cAttendances.Where(a => a.StudentId == st.Id).ToList();
                    var stSess = cSessions.Where(s => s.StudentId == st.Id).ToList();

                    int stPresent = stAtt.Count(a => a.Status == AttendanceStatus.Present);
                    int stAbsent = stAtt.Count(a => a.Status == AttendanceStatus.Absent);
                    int stLate = stAtt.Count(a => a.Status == AttendanceStatus.Late);
                    int stTotalAtt = stAtt.Count;
                    int stRate = stTotalAtt > 0 ? (int)Math.Round((double)stPresent / stTotalAtt * 100) : 100;

                    int stMem = stSess.Count(s => s.RecitationType == RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
                    int stRev = stSess.Count(s => s.RecitationType == RecitationType.Revision && s.Assessment != AssessmentLevel.DidNotRecite);
                    int stDidNotRecite = stSess.Count(s => s.Assessment == AssessmentLevel.DidNotRecite);
                    int stVerses = stSess.Where(s => s.Assessment != AssessmentLevel.DidNotRecite).Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));

                    return new
                    {
                        st.Id,
                        st.FullName,
                        IdentityNumber = st.StudentIdentityNumber ?? "",
                        Mobile = st.StudentMobile ?? st.FamilyContact ?? "",
                        TargetAjzaa = st.TargetAjzaaCount,
                        CompletedAjzaa = st.CompletedAjzaa,
                        PresentCount = stPresent,
                        AbsentCount = stAbsent,
                        LateCount = stLate,
                        AttendanceRate = stRate,
                        TotalRecitations = stSess.Count,
                        MemorizationSessions = stMem,
                        RevisionSessions = stRev,
                        DidNotReciteSessions = stDidNotRecite,
                        TotalVerses = stVerses
                    };
                }).ToList();

                circleDataList.Add(new
                {
                    c.Id,
                    c.Name,
                    TeacherName = c.Teacher != null ? c.Teacher.FullName : "غير محدد",
                    StudentCount = circleStudents.Count,
                    PresentCount = presentCount,
                    AbsentCount = absentCount,
                    LateCount = lateCount,
                    AttendanceRate = attendanceRate,
                    CompletedSessions = cSessions.Count,
                    MemorizationSessions = memSessions,
                    RevisionSessions = revSessions,
                    DidNotReciteSessions = didNotReciteSessions,
                    TotalVerses = totalVerses,
                    QualityScore = qualityScore,
                    Students = studentBreakdown
                });
            }

            // Aggregate scientific courses
            var courseDataList = new List<object>();
            foreach (var crs in courses)
            {
                var enrollments = crs.Enrollments.ToList();
                var crsAtt = courseAttendances.Where(ca => ca.CourseId == crs.Id).ToList();

                int crsPresent = crsAtt.Count(a => a.Status == AttendanceStatus.Present);
                int crsTotalAtt = crsAtt.Count;
                int crsRate = crsTotalAtt > 0 ? (int)Math.Round((double)crsPresent / crsTotalAtt * 100) : 100;
                int passedCount = enrollments.Count(e => e.Status == "Passed" || e.Status == "Certified");

                var enrolledStudents = enrollments.Select(e =>
                {
                    var stAtt = crsAtt.Where(a => a.StudentId == e.StudentId).ToList();
                    int stPresent = stAtt.Count(a => a.Status == AttendanceStatus.Present);
                    int stAbsent = stAtt.Count(a => a.Status == AttendanceStatus.Absent);

                    return new
                    {
                        e.StudentId,
                        StudentName = e.Student != null ? e.Student.FullName : "طالب غير معروف",
                        e.Status,
                        e.Grade,
                        PresentCount = stPresent,
                        AbsentCount = stAbsent
                    };
                }).ToList();

                courseDataList.Add(new
                {
                    crs.Id,
                    crs.Name,
                    crs.Description,
                    TeacherName = crs.Teacher != null ? crs.Teacher.FullName : "غير محدد",
                    EnrolledCount = enrollments.Count,
                    PassedCount = passedCount,
                    AttendanceRate = crsRate,
                    Students = enrolledStudents
                });
            }

            // Global rates
            int avgAttendanceRate = allTotalAttCount > 0 ? (int)Math.Round((double)allPresentCount / allTotalAttCount * 100) : 95;
            int excellenceRate = allTotalRecitations > 0 ? (int)Math.Round((double)allExcellenceCount / allTotalRecitations * 100) : 90;

            return Ok(new
            {
                Stats = new
                {
                    TotalCircles = circles.Count,
                    TotalStudents = circles.Sum(c => c.Students.Count(s => s.IsActive)),
                    TotalSessions = allTotalRecitations,
                    MemorizationSessions = allMemorizationCount,
                    RevisionSessions = allRevisionCount,
                    DidNotReciteSessions = allDidNotReciteCount,
                    TotalVerses = allTotalVerses,
                    AvgAttendanceRate = avgAttendanceRate,
                    ExcellenceRate = excellenceRate,
                    TotalCourses = courses.Count,
                    TotalCourseEnrollments = courses.Sum(c => c.Enrollments.Count)
                },
                Circles = circleDataList,
                Courses = courseDataList
            });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[QualityController.GetOverview Warning] {ex.Message}");
            return Ok(new
            {
                Stats = new
                {
                    TotalCircles = 0,
                    TotalStudents = 0,
                    TotalSessions = 0,
                    MemorizationSessions = 0,
                    RevisionSessions = 0,
                    DidNotReciteSessions = 0,
                    TotalVerses = 0,
                    AvgAttendanceRate = 95,
                    ExcellenceRate = 90,
                    TotalCourses = 0,
                    TotalCourseEnrollments = 0
                },
                Circles = new List<object>(),
                Courses = new List<object>()
            });
        }
    }
}
