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
    private readonly ILogger<QualityController> _logger;

    public QualityController(AppDbContext db, ILogger<QualityController> logger)
    {
        _db = db;
        _logger = logger;
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

            var exams = await _db.ExamNominations.Include(x => x.Result).AsNoTracking().ToListAsync();
            var visits = await _db.QualityVisits.AsNoTracking().Where(v => !v.IsSubstituteModeActive).ToListAsync();
            var circleDays = await _db.CircleDays.AsNoTracking().ToListAsync();
            var today = CenterClock.Today;
            // Aggregate circle data
            var circleDataList = new List<object>();

            int allPresentCount = 0;
            int allTotalAttCount = 0;
            int allExcellenceCount = 0;
            int allTotalRecitations = sessions.Count;
            int allMemorizationCount = sessions.Count(s => s.RecitationType == RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
            int allRevisionCount = sessions.Count(s => s.RecitationType != RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
            int allDidNotReciteCount = sessions.Count(s => s.Assessment == AssessmentLevel.DidNotRecite);
            int allTotalVerses = sessions.Where(s => s.Assessment != AssessmentLevel.DidNotRecite).Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));

            foreach (var c in circles)
            {
                var circleStudents = c.Students.Where(s => s.IsActive).ToList();
                var studentIds = circleStudents.Select(s => s.Id).ToHashSet();

                var cAttendances = attendances.Where(a => a.CircleId == c.Id).ToList();
                var cSessions = sessions.Where(s => s.RecordedCircleId == c.Id || (s.RecordedCircleId == null && studentIds.Contains(s.StudentId))).ToList();

                int presentCount = cAttendances.Count(a => (a.Status == AttendanceStatus.Present || a.Status == AttendanceStatus.Late));
                int absentCount = cAttendances.Count(a => a.Status == AttendanceStatus.Absent);
                int lateCount = cAttendances.Count(a => a.Status == AttendanceStatus.Late);
                int totalAtt = cAttendances.Count;

                allPresentCount += presentCount;
                allTotalAttCount += totalAtt;

                int cExcellence = cSessions.Count(s => s.Assessment == AssessmentLevel.Excellent);
                allExcellenceCount += cExcellence;

                int attendanceRate = totalAtt > 0 ? (int)Math.Round((double)presentCount / totalAtt * 100) : 0;
                int memSessions = cSessions.Count(s => s.RecitationType == RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
                int revSessions = cSessions.Count(s => s.RecitationType != RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
                int didNotReciteSessions = cSessions.Count(s => s.Assessment == AssessmentLevel.DidNotRecite);
                int totalVerses = cSessions.Where(s => s.Assessment != AssessmentLevel.DidNotRecite).Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));

                var monthStart = new DateOnly(today.Year, today.Month, 1);
                var monthDays = circleDays.Where(d => d.CircleId == c.Id && d.Date >= monthStart && d.Date <= today).ToList();
                var monthAtt = cAttendances.Where(a => a.SessionDate >= monthStart && a.SessionDate <= today).ToList();
                var monthExams = exams.Where(e => studentIds.Contains(e.StudentId) && e.Status == "Completed" && e.Result != null && e.ExamDate.HasValue && DateOnly.FromDateTime(e.ExamDate.Value) >= monthStart && DateOnly.FromDateTime(e.ExamDate.Value) <= today).ToList();
                var monthVisits = visits.Where(v => v.CircleId == c.Id && v.VisitDate >= monthStart && v.VisitDate <= today).ToList();
                double teacherRate = ReportService.Percentage(monthDays.Count(d => d.OpenedAt != null && d.Status != "Absent"), monthDays.Count(d => d.Status != "Suspended"));
                double studentRate = ReportService.Percentage(monthAtt.Count(a => a.Status is AttendanceStatus.Present or AttendanceStatus.Late), monthAtt.Count);
                double examRate = monthExams.Count > 0 ? monthExams.Average(e => e.Result!.Grade) : 0;
                double visitRate = monthVisits.Count > 0 ? monthVisits.Average(v => v.OverallQualityScore) : 0;
                bool ratingComplete = monthDays.Count > 0 && monthAtt.Count > 0 && monthExams.Count > 0 && monthVisits.Count > 0;
                double? rating = ratingComplete ? Math.Round(teacherRate * .25 + studentRate * .25 + examRate * .30 + visitRate * .20, 1) : null;
                string qualityScore = rating == null ? "بيانات التقييم غير مكتملة" : rating >= 90 ? "ممتاز" : rating >= 75 ? "جيد جداً" : "يحتاج متابعة";
                var week1 = cSessions.Where(s => s.SessionDate > today.AddDays(-7) && s.SessionDate <= today).ToList();
                var week2 = cSessions.Where(s => s.SessionDate > today.AddDays(-14) && s.SessionDate <= today.AddDays(-7)).ToList();
                bool declineAlert = week1.Count > 0 && week2.Count > 0 && week1.Average(ReportService.Score) < 75 && week2.Average(ReportService.Score) < 75;
                double newPages = cSessions.Where(s => s.RecitationType == RecitationType.Memorization).Sum(ReportService.Pages);
                double reviewPages = cSessions.Where(s => s.RecitationType != RecitationType.Memorization).Sum(ReportService.Pages);
                double? reviewToNewPercent = newPages > 0 ? Math.Round(reviewPages / newPages * 100, 1) : null;

                // Breakdown of students in this circle
                var studentBreakdown = circleStudents.Select(st =>
                {
                    var stAtt = cAttendances.Where(a => a.StudentId == st.Id).ToList();
                    var stSess = cSessions.Where(s => s.StudentId == st.Id).ToList();

                    int stPresent = stAtt.Count(a => (a.Status == AttendanceStatus.Present || a.Status == AttendanceStatus.Late));
                    int stAbsent = stAtt.Count(a => a.Status == AttendanceStatus.Absent);
                    int stLate = stAtt.Count(a => a.Status == AttendanceStatus.Late);
                    int stTotalAtt = stAtt.Count;
                    int stRate = stTotalAtt > 0 ? (int)Math.Round((double)stPresent / stTotalAtt * 100) : 0;

                    int stMem = stSess.Count(s => s.RecitationType == RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
                    int stRev = stSess.Count(s => s.RecitationType != RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
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
                    Rating = rating, RatingComplete = ratingComplete,
                    RatingComponents = new { TeacherAttendance = teacherRate, StudentAttendance = studentRate, Exams = examRate, Visits = visitRate },
                    DeclineAlert = declineAlert, ReviewToNewPercent = reviewToNewPercent,
                    ReviewWarning = reviewToNewPercent.HasValue && reviewToNewPercent < 70,
                    Students = studentBreakdown
                });
            }

            // Aggregate scientific courses
            var courseDataList = new List<object>();
            foreach (var crs in courses)
            {
                var enrollments = crs.Enrollments.ToList();
                var crsAtt = courseAttendances.Where(ca => ca.CourseId == crs.Id).ToList();

                int crsPresent = crsAtt.Count(a => (a.Status == AttendanceStatus.Present || a.Status == AttendanceStatus.Late));
                int crsTotalAtt = crsAtt.Count;
                int crsRate = crsTotalAtt > 0 ? (int)Math.Round((double)crsPresent / crsTotalAtt * 100) : 0;
                int passedCount = enrollments.Count(e => e.Status == "Passed" || e.Status == "Certified");

                var enrolledStudents = enrollments.Select(e =>
                {
                    var stAtt = crsAtt.Where(a => a.StudentId == e.StudentId).ToList();
                    int stPresent = stAtt.Count(a => (a.Status == AttendanceStatus.Present || a.Status == AttendanceStatus.Late));
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
            int avgAttendanceRate = allTotalAttCount > 0 ? (int)Math.Round((double)allPresentCount / allTotalAttCount * 100) : 0;
            int excellenceRate = allTotalRecitations > 0 ? (int)Math.Round((double)allExcellenceCount / allTotalRecitations * 100) : 0;

            return Ok(new
            {
                Stats = new
                {
                    TotalCircles = circles.Count,
                    TotalStudents = circles.Sum(c => c.Students.Count(s => s.IsActive)),
                    TotalSessions = allTotalRecitations,
                    TotalAttendanceRecords = allTotalAttCount,
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
            _logger.LogError(ex, "Failed to load quality overview for user {UserId}", User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value);
            return StatusCode(503, new { error = "تعذر تحميل مؤشرات الجودة. أعد المحاولة." });
        }
    }

    [HttpGet("visits")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.ExamSupervisor)]
    public async Task<IActionResult> GetVisits([FromQuery] int? circleId)
    {
        var query = _db.QualityVisits.Include(v => v.Circle).AsNoTracking().AsQueryable();
        if (circleId.HasValue) query = query.Where(v => v.CircleId == circleId.Value);

        var list = await query.OrderByDescending(v => v.VisitDate).ThenByDescending(v => v.Id).Take(50).ToListAsync();
        return Ok(list.Select(v => new
        {
            v.Id,
            v.CircleId,
            CircleName = v.Circle?.Name ?? "حلقة قرآنية",
            v.SupervisorName,
            VisitDate = v.VisitDate.ToString("yyyy-MM-dd"),
            v.PunctualityScore,
            v.ClassManagementScore,
            v.TajweedCorrectionScore,
            v.OverallQualityScore,
            v.Notes,
            v.SpotCheckedStudentsJson,
            v.IsSubstituteModeActive,
            CreatedAt = v.CreatedAt.ToString("yyyy-MM-dd HH:mm")
        }));
    }

    [HttpPost("visits")]
    [Idempotent]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.ExamSupervisor)]
    public async Task<IActionResult> CreateVisit([FromBody] CreateQualityVisitDto dto)
    {
        if (dto.CircleId <= 0) return BadRequest(new { error = "يرجى اختيار الحلقة المراد زيارتها." });

        var circle = await _db.Circles.FindAsync(dto.CircleId);
        if (circle == null) return NotFound(new { error = "الحلقة غير موجودة." });

        if (dto.PunctualityScore is < 0 or > 100 || dto.ClassManagementScore is < 0 or > 100 || dto.TajweedCorrectionScore is < 0 or > 100)
            return BadRequest(new { error = "درجات الزيارة يجب أن تكون بين 0 و100." });
        if (dto.IsSubstituteModeActive) return BadRequest(new { error = "التغطية تُفعّل من سجل غياب المعلم فقط." });
        if (!string.IsNullOrWhiteSpace(dto.SpotCheckedStudentsJson))
        {
            try {
                using var doc = System.Text.Json.JsonDocument.Parse(dto.SpotCheckedStudentsJson);
                if (doc.RootElement.ValueKind != System.Text.Json.JsonValueKind.Array || doc.RootElement.GetArrayLength() > 3) return BadRequest();
                var ids = await _db.Students.Where(s => s.CircleId == dto.CircleId && s.IsActive).Select(s => s.Id).ToListAsync();
                foreach (var item in doc.RootElement.EnumerateArray())
                    if (!item.TryGetProperty("studentId", out var id) || !ids.Contains(id.GetInt32()) ||
                        !item.TryGetProperty("score", out var score) || score.GetDouble() < 0 || score.GetDouble() > 100) return BadRequest(new { error = "تحقق من طلاب العينة ودرجاتهم." });
            } catch (System.Text.Json.JsonException) { return BadRequest(); }
        }
        int overall = (int)Math.Round((dto.PunctualityScore * 0.25) + (dto.ClassManagementScore * 0.25) + (dto.TajweedCorrectionScore * 0.50));

        var visit = new QualityVisit
        {
            CircleId = dto.CircleId,
            SupervisorName = FakeAuth.GetUsername(HttpContext) ?? "مشرف الجودة",
            VisitDate = dto.VisitDate ?? DateOnly.FromDateTime(DateTime.Today),
            PunctualityScore = Math.Clamp(dto.PunctualityScore, 0, 100),
            ClassManagementScore = Math.Clamp(dto.ClassManagementScore, 0, 100),
            TajweedCorrectionScore = Math.Clamp(dto.TajweedCorrectionScore, 0, 100),
            OverallQualityScore = overall,
            Notes = dto.Notes,
            SpotCheckedStudentsJson = dto.SpotCheckedStudentsJson,
            IsSubstituteModeActive = dto.IsSubstituteModeActive
        };

        _db.QualityVisits.Add(visit);
        await _db.SaveChangesAsync();

        return Ok(new { success = true, id = visit.Id, overallQualityScore = overall, message = "تم توثيق الزيارة الرقابية بنجاح." });
    }

    [HttpGet("spot-check/{circleId}")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.ExamSupervisor)]
    public async Task<IActionResult> GetSpotCheckCandidates(int circleId)
    {
        var circle = await _db.Circles.Include(c => c.Teacher).FirstOrDefaultAsync(c => c.Id == circleId);
        if (circle == null) return NotFound(new { error = "الحلقة غير موجودة." });

        var students = await _db.Students.Where(s => s.CircleId == circleId && s.IsActive).ToListAsync();
        if (students.Count == 0) return Ok(new { circleId, circleName = circle.Name, candidates = new List<object>() });

        var random = new Random();
        var selected = students.OrderBy(_ => random.Next()).Take(Math.Min(3, students.Count)).Select(s => new
        {
            s.Id,
            s.FullName,
            s.StudentIdentityNumber,
            s.CompletedAjzaa,
            s.TargetAjzaaCount,
            s.PreviousQuranMemorization
        }).ToList();

        return Ok(new
        {
            circleId,
            circleName = circle.Name,
            teacherName = circle.Teacher?.FullName ?? "غير محدد",
            candidates = selected
        });
    }

    [HttpPost("substitute-mode")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.ExamSupervisor)]
    public async Task<IActionResult> ToggleSubstituteMode([FromBody] SubstituteModeDto dto)
    {
        var service = new TeacherAttendanceService(_db);
        if (!await service.CanManageAsync(HttpContext)) return Forbid();
        try {
            var actor = FakeAuth.GetUserId(HttpContext)!.Value;
            await service.AssignAsync(dto.CircleId, dto.Date ?? CenterClock.Today, dto.Activate ? dto.SubstituteUserId ?? actor : null,
                dto.Reason ?? "غياب المعلم الأصلي", actor, FakeAuth.GetUsername(HttpContext) ?? "");
            return Ok(new { success = true, isSubstituteModeActive = dto.Activate, message = "تم تحديث تكليف البديل في كشف حضور المعلمين." });
        } catch (ArgumentException e) { return BadRequest(new { error = e.Message }); }
    }
}

public record CreateQualityVisitDto(
    int CircleId,
    string? SupervisorName,
    DateOnly? VisitDate,
    int PunctualityScore,
    int ClassManagementScore,
    int TajweedCorrectionScore,
    string? Notes,
    string? SpotCheckedStudentsJson,
    bool IsSubstituteModeActive
);

public record SubstituteModeDto(int CircleId, string? SupervisorName, string? Reason, bool Activate, int? SubstituteUserId = null, DateOnly? Date = null);

