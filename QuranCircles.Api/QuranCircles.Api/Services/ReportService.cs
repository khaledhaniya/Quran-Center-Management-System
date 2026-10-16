using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class ReportService
{
    private readonly AppDbContext _db;
    public ReportService(AppDbContext db) => _db = db;

    public async Task<SummaryReportDto> GetSummaryAsync(DateOnly from, DateOnly to)
    {
        try
        {
            var totalStudents = await _db.Students.CountAsync(s => s.IsActive);
            var totalTeachers = await _db.Teachers.CountAsync(t => t.IsActive);
            var totalCircles = await _db.Circles.CountAsync(c => c.IsActive);

            var sessions = await _db.Sessions
                .Where(s => s.SessionDate >= from && s.SessionDate <= to)
                .ToListAsync();

            var totalVerses = sessions.Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));

            var absenceCount = await _db.Attendances
                .CountAsync(a => a.SessionDate >= from && a.SessionDate <= to && a.Status == AttendanceStatus.Absent);

            var breakdown = sessions
                .GroupBy(s => s.Assessment)
                .ToDictionary(
                    g => SessionService.AssessmentText(g.Key),
                    g => g.Count());

            return new SummaryReportDto(
                from, to,
                totalStudents, totalTeachers, totalCircles,
                sessions.Count, totalVerses, absenceCount,
                breakdown
            );
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ReportService.GetSummaryAsync Warning] {ex.Message}");
            int sCount = 0, tCount = 0, cCount = 0;
            try { sCount = await _db.Students.CountAsync(s => s.IsActive); } catch { }
            try { tCount = await _db.Teachers.CountAsync(t => t.IsActive); } catch { }
            try { cCount = await _db.Circles.CountAsync(c => c.IsActive); } catch { }

            return new SummaryReportDto(
                from, to,
                sCount, tCount, cCount,
                0, 0, 0,
                new Dictionary<string, int>()
            );
        }
    }


    public async Task<List<ChildProgressDto>> GetChildrenProgressAsync(int parentId)
    {
        var children = await _db.Students
            .Include(s => s.Circle)
            .Where(s => s.ParentId == parentId)
            .ToListAsync();

        return await BuildChildProgressDtosAsync(children);
    }

    public async Task<List<ChildProgressDto>> GetChildrenProgressForUserAsync(User user)
    {
        if (user == null) return new List<ChildProgressDto>();

        var matchedStudents = await GetSmartChildrenForParentAsync(user);
        return await BuildChildProgressDtosAsync(matchedStudents);
    }

    private async Task<List<ChildProgressDto>> BuildChildProgressDtosAsync(List<Student> children)
    {
        var result = new List<ChildProgressDto>();
        var distinctChildren = children.GroupBy(c => c.Id).Select(g => g.First()).ToList();

        foreach (var child in distinctChildren)

        {
            var sessions = await _db.Sessions
                .Where(s => s.StudentId == child.Id)
                .OrderByDescending(s => s.SessionDate)
                .ToListAsync();

            var absence = await _db.Attendances
                .CountAsync(a => a.StudentId == child.Id && a.Status == AttendanceStatus.Absent);
            var late = await _db.Attendances
                .CountAsync(a => a.StudentId == child.Id && a.Status == AttendanceStatus.Late);

            var recent = sessions.Take(5).Select(s => new SessionDto(
                s.Id, s.StudentId, child.FullName,
                s.SessionDate, s.SurahName, s.FromVerse, s.ToVerse,
                s.Assessment, SessionService.AssessmentText(s.Assessment), s.Notes, s.ViaLottery
            )).ToList();

            var talents = await _db.TalentRecords
                .Include(t => t.SupervisorTeacher)
                .Where(t => t.StudentId == child.Id)
                .OrderByDescending(t => t.EventDate)
                .Select(t => (object)new {
                    t.Id,
                    t.TalentType,
                    t.Title,
                    t.PreparationMethod,
                    t.SpeechContent,
                    t.Occasion,
                    EventDate = t.EventDate.ToString("yyyy-MM-dd"),
                    t.SupervisorTeacherId,
                    SupervisorTeacherName = t.SupervisorTeacher != null ? t.SupervisorTeacher.FullName : "غير معين",
                    t.MediaUrl,
                    t.MediaType,
                    t.EvaluationScore,
                    t.PerformanceNotes
                })
                .ToListAsync();

            result.Add(new ChildProgressDto(
                child.Id, child.FullName, child.Circle?.Name,
                sessions.Count, absence, late, recent,
                talents.Count > 0, talents
            ));
        }

        return result;
    }

    public async Task<List<Student>> GetSmartChildrenForParentAsync(User parentUser)
    {
        if (parentUser.Teacher == null && parentUser.TeacherId.HasValue)
            parentUser.Teacher = await _db.Teachers.FindAsync(parentUser.TeacherId.Value);
        return (await _db.Students.Include(s => s.Circle).AsNoTracking().ToListAsync())
            .Where(s => ParentLinks.IsChild(parentUser, s)).OrderBy(s => s.Id).ToList();
    }

    public async Task<object> GetExecutiveDashboardAsync(DateOnly from, DateOnly to)
    {
        try
        {
            var today = CenterClock.Today;
            var now = CenterClock.Now;

            // 1. Core Counts
            var allStudents = await _db.Students.Include(s => s.Circle).AsNoTracking().ToListAsync();
            var allTeachers = await _db.Teachers.AsNoTracking().ToListAsync();
            var allCircles = await _db.Circles.Include(c => c.Teacher).AsNoTracking().ToListAsync();
            var users = await _db.Users.Include(u => u.Teacher).Where(u => u.Role != UserRole.Student).AsNoTracking().ToListAsync();
            var allParents = users.Where(u => u.Role == UserRole.Parent || allStudents.Any(s => ParentLinks.IsChild(u, s))).ToList();
            var schedules = await _db.CircleSchedules.AsNoTracking().ToListAsync();

            int totalStudents = allStudents.Count;
            int totalStudentsActive = allStudents.Count(s => s.IsActive);
            int totalStudentsInactive = allStudents.Count(s => !s.IsActive);

            int totalCircles = allCircles.Count;
            int activeCircles = allCircles.Count(c => c.IsActive);
            var dashboardSettings = await _db.SystemSettings.AsNoTracking().FirstOrDefaultAsync();
            int maxCapPerCircle = Math.Max(1, dashboardSettings?.MaxStudentsPerCircle ?? 20);
            int totalCapacity = allCircles.Where(c => c.IsActive).Sum(c => schedules.FirstOrDefault(x => x.CircleId == c.Id)?.Capacity ?? maxCapPerCircle);
            double capacityUtilization = totalCapacity > 0 ? Math.Round((double)allStudents.Count(s => s.IsActive && allCircles.Any(c => c.Id == s.CircleId && c.IsActive)) / totalCapacity * 100, 1) : 0;

            int totalTeachers = allTeachers.Count;
            int activeTeachers = allTeachers.Count(t => t.IsActive);

            // Parents linking audit
            int totalParentsCount = allParents.Count;
            int linkedParentsCount = allParents.Count(p => p.IsActive && allStudents.Any(s => ParentLinks.IsChild(p, s)));
            int unlinkedParentsCount = Math.Max(0, totalParentsCount - linkedParentsCount);
            double parentLinkPercent = Percentage(linkedParentsCount, totalParentsCount);

            // A completed Juz 30 alone does not mean the full Quran is completed.
            var khatimunList = allStudents.Where(HasCompletedQuran).ToList();
            int khatimunTotal = khatimunList.Count;

            var currentYear = now.Year;
            var currentMonth = now.Month;

            var examNominations = await _db.ExamNominations
                .Include(x => x.Result)
                .AsNoTracking()
                .ToListAsync();

            int khatimunThisYear = examNominations.Where(e => e.Status == "Completed" && e.NominationType == "Quran" && (e.JuzStart == 1 && e.JuzEnd == 30 && e.Result != null && e.Result.Grade >= (dashboardSettings?.PassingScoreThreshold ?? 70)) && e.ExamDate.HasValue && e.ExamDate.Value.Year == currentYear).Select(e => e.StudentId).Distinct().Count();
            int khatimunThisMonth = examNominations.Where(e => e.Status == "Completed" && e.NominationType == "Quran" && (e.JuzStart == 1 && e.JuzEnd == 30 && e.Result != null && e.Result.Grade >= (dashboardSettings?.PassingScoreThreshold ?? 70)) && e.ExamDate.HasValue && e.ExamDate.Value.Month == currentMonth && e.ExamDate.Value.Year == currentYear).Select(e => e.StudentId).Distinct().Count();

            int huffazCount = await _db.HuffazMembers.CountAsync();
            int huffazInIjaza = await _db.HuffazMembers.CountAsync(h => h.IsActive && h.Riwayah != null && (h.Riwayah.Contains("إجازة") || h.Riwayah.Contains("سند")));
            int tathbeetCount = await _db.HuffazMembers.CountAsync(h => h.IsActive && h.RevisionPlan != null && h.RevisionPlan.Contains("تثبيت"));

            // 2. Real-Time Operations Pulse (اليوم الحالي)
            var todayAttendances = await _db.Attendances
                .Where(a => a.SessionDate == today)
                .AsNoTracking()
                .ToListAsync();

            int todayStudentsPresent = todayAttendances.Count(a => a.Status == AttendanceStatus.Present);
            int todayStudentsExcused = todayAttendances.Count(a => a.Status == AttendanceStatus.ExcusedAbsent);
            int todayStudentsAbsent = todayAttendances.Count(a => a.Status == AttendanceStatus.Absent);
            int todayStudentsLate = todayAttendances.Count(a => a.Status == AttendanceStatus.Late);
            int todayTotalAtt = todayAttendances.Count;
            double todayAttendanceRate = todayTotalAtt > 0 ? Math.Round((double)(todayStudentsPresent + todayStudentsLate) / todayTotalAtt * 100, 1) : 0;

            var todaySessions = await _db.Sessions.Include(s => s.Student)
                .Where(s => s.SessionDate == today)
                .AsNoTracking()
                .ToListAsync();

            int todaySessionsCount = todaySessions.Count;
            int todayVersesRecited = todaySessions.Where(s => s.Assessment != AssessmentLevel.DidNotRecite).Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));
            double todayPagesRecited = Math.Round(todaySessions.Sum(Pages), 2);

            // Teacher Presence & Circle Start Status (Implicit Detection)
            var days = await _db.CircleDays.AsNoTracking().Where(d => d.Date == today).ToListAsync();
            var todayStartedCircleIds = days.Where(d => d.OpenedAt.HasValue).Select(d => d.CircleId).ToHashSet();
            int todayCirclesStarted = allCircles.Count(c => c.IsActive && todayStartedCircleIds.Contains(c.Id));
            var scheduledToday = schedules.Where(s => CircleOperations.ScheduledOn(s, today) && allCircles.Any(c => c.Id == s.CircleId && c.IsActive)).ToList();
            int todayCirclesLateOrPending = scheduledToday.Count(s => !todayStartedCircleIds.Contains(s.CircleId) &&
                TimeOnly.Parse(s.StartTime).ToTimeSpan().Add(TimeSpan.FromMinutes(15)) <= now.TimeOfDay &&
                !days.Any(d => d.CircleId == s.CircleId && d.Status == "Suspended"));
            var substituteIds = days.Where(d => d.OpenedAt.HasValue && d.Status == "Absent" && d.SubstituteUserId.HasValue)
                .Select(d => d.SubstituteUserId!.Value).ToHashSet();
            var presentTeacherIds = days.Where(d => d.OpenedAt.HasValue && d.Status != "Absent" && d.TeacherId.HasValue)
                .Select(d => d.TeacherId!.Value).ToHashSet();
            foreach (var substitute in users.Where(u => substituteIds.Contains(u.Id) && u.TeacherId.HasValue))
                presentTeacherIds.Add(substitute.TeacherId!.Value);
            int todayTeachersPresent = presentTeacherIds.Count;

            // 3. Range-Based Data (from - to)
            var rangeSessions = await _db.Sessions.Include(s => s.Student)
                .Where(s => s.SessionDate >= from && s.SessionDate <= to)
                .AsNoTracking()
                .ToListAsync();

            var rangeAttendances = await _db.Attendances
                .Where(a => a.SessionDate >= from && a.SessionDate <= to)
                .AsNoTracking()
                .ToListAsync();

            int rangeAbsenceCount = rangeAttendances.Count(a => a.Status == AttendanceStatus.Absent || a.Status == AttendanceStatus.ExcusedAbsent);
            int rangeTotalVerses = rangeSessions.Where(s => s.Assessment != AssessmentLevel.DidNotRecite).Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));
            int rangeTotalSessions = rangeSessions.Count;

            // 4. Quality & Circle Performance
            var circlePerformance = allCircles.Where(c => c.IsActive).Select(c =>
            {
                var cAtts = rangeAttendances.Where(a => a.CircleId == c.Id).ToList();
                var cSess = rangeSessions.Where(s => (s.RecordedCircleId ?? s.Student?.CircleId) == c.Id).ToList();
                int cPresent = cAtts.Count(a => a.Status is AttendanceStatus.Present or AttendanceStatus.Late);
                int cTotalAtt = cAtts.Count;
                double rate = cTotalAtt > 0 ? Math.Round((double)cPresent / cTotalAtt * 100, 1) : 0;
                int verses = cSess.Where(s => s.Assessment != AssessmentLevel.DidNotRecite).Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));

                return new
                {
                    c.Id,
                    c.Name,
                    CircleName = c.Name,
                    TeacherName = c.Teacher != null ? c.Teacher.FullName : "غير محدد",
                    StudentsCount = allStudents.Count(s => s.CircleId == c.Id && s.IsActive),
                    AttendanceRate = rate,
                    AttendanceRecords = cTotalAtt,
                    SessionsCount = cSess.Count,
                    VersesRecited = verses
                };
            }).ToList();

            // No attendance records means unmeasured, not 0% attendance.
            var measuredCircles = circlePerformance.Where(c => c.AttendanceRecords > 0).ToList();
            var topPerformingCircles = measuredCircles.OrderByDescending(c => c.AttendanceRate).ThenByDescending(c => c.VersesRecited).Take(5).ToList();
            var lowestPerformingCircles = measuredCircles.OrderBy(c => c.AttendanceRate).ThenBy(c => c.SessionsCount).Take(5).ToList();

            // Exam indicators
            var periodExams = examNominations.Where(e => e.ExamDate.HasValue && DateOnly.FromDateTime(e.ExamDate.Value) >= from && DateOnly.FromDateTime(e.ExamDate.Value) <= to).ToList();
            int totalExamsCompleted = periodExams.Count(e => e.Status == "Completed" && e.Result != null);
            int passedExams = periodExams.Count(e => e.Status == "Completed" && e.Result != null && e.Result.Grade >= (dashboardSettings?.PassingScoreThreshold ?? 70));
            double examPassRate = totalExamsCompleted > 0 ? Math.Round((double)passedExams / totalExamsCompleted * 100, 1) : 0;
            int qualifiedStudentsForExam = examNominations.Where(e => e.Status is "Pending" or "Scheduled").Select(e => e.StudentId).Distinct().Count();

            // Early Warning Absences (3 consecutive unexcused or 10 in month)
            var studentAbsences = rangeAttendances
                .Where(a => a.Status == AttendanceStatus.Absent)
                .GroupBy(a => a.StudentId)
                .Select(g => new { StudentId = g.Key, AbsentDates = g.Select(x => x.SessionDate).Distinct().OrderBy(d => d).ToList() })
                .ToList();

            var consecutiveAbsenceAlerts = new List<object>();
            var monthlyAbsenceAlerts = new List<object>();

            foreach (var sa in studentAbsences)
            {
                var st = allStudents.FirstOrDefault(s => s.Id == sa.StudentId);
                if (st == null) continue;

                // Check 10 days in month
                if (sa.AbsentDates.GroupBy(d => new { d.Year, d.Month }).Any(g => g.Count() >= 10))
                {
                    monthlyAbsenceAlerts.Add(new
                    {
                        st.Id,
                        st.FullName,
                        CircleName = st.Circle?.Name ?? "غير مسند",
                        Contact = st.FamilyContact ?? st.StudentMobile ?? "",
                        AbsenceCount = sa.AbsentDates.Count
                    });
                }

                // Check 3 consecutive days
                bool hasThreeConsecutive = false;
                for (int i = 0; i < sa.AbsentDates.Count - 2; i++)
                {
                    if (sa.AbsentDates[i + 1].DayNumber - sa.AbsentDates[i].DayNumber == 1 &&
                        sa.AbsentDates[i + 2].DayNumber - sa.AbsentDates[i + 1].DayNumber == 1)
                    {
                        hasThreeConsecutive = true;
                        break;
                    }
                }
                if (hasThreeConsecutive)
                {
                    consecutiveAbsenceAlerts.Add(new
                    {
                        st.Id,
                        st.FullName,
                        CircleName = st.Circle?.Name ?? "غير مسند",
                        Contact = st.FamilyContact ?? st.StudentMobile ?? "",
                        DaysCount = sa.AbsentDates.Count,
                        LastAbsentDate = sa.AbsentDates.Last().ToString("yyyy-MM-dd")
                    });
                }
            }

            // 5. Specialized Programs & Activities
            int preacherYouthCount = await _db.TalentRecords.Where(t => t.TalentType.Contains("واعظ") || t.TalentType.Contains("خطابة")).Select(t => t.StudentId).Distinct().CountAsync();
            int preacherSpeechesCount = await _db.TalentRecords.Where(t => t.TalentType.Contains("الأصوات") || t.TalentType.Contains("تلاوة") || t.TalentType.Contains("أذان")).Select(t => t.StudentId).Distinct().CountAsync();
            var courseEnrollments = await _db.CourseEnrollments.AsNoTracking().ToListAsync();
            int certsMonth = courseEnrollments.Count(e => !string.IsNullOrWhiteSpace(e.CertificateCode) && e.CertificateDate.HasValue && e.CertificateDate.Value.Month == currentMonth && e.CertificateDate.Value.Year == currentYear);
            int certsTotal = courseEnrollments.Count(e => !string.IsNullOrWhiteSpace(e.CertificateCode));

            // 6. Quranic Flow & Cumulative Memorization
            int memorizationCount = rangeSessions.Count(s => s.RecitationType == RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
            int revisionCount = rangeSessions.Count(s => s.RecitationType != RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
            double revisionRatio = memorizationCount > 0 ? Math.Round((double)revisionCount / memorizationCount, 2) : 0;
            double reviewPercent = Percentage(revisionCount, revisionCount + memorizationCount);
            double newPercent = Percentage(memorizationCount, revisionCount + memorizationCount);
            int rangeDays = Math.Max(1, to.DayNumber - from.DayNumber + 1);
            // Page counts are estimates (15 verses/page), not exact Mushaf page positions.
            double dailyPagesEstimate = totalStudentsActive > 0 ? Math.Round(rangeSessions.Where(s => s.RecitationType == RecitationType.Memorization).Sum(Pages) / totalStudentsActive / rangeDays, 2) : 0;
            double weeklyPagesEstimate = Math.Round(dailyPagesEstimate * 7, 2);

            int juz1to5 = allStudents.Count(s => {
                int count = CompletedParts(s);
                return count >= 1 && count <= 5;
            });
            int juz6to10 = allStudents.Count(s => {
                int count = CompletedParts(s);
                return count >= 6 && count <= 10;
            });
            int juz11to20 = allStudents.Count(s => {
                int count = CompletedParts(s);
                return count >= 11 && count <= 20;
            });
            int juz21to30 = allStudents.Count(s => {
                int count = CompletedParts(s);
                return count >= 21;
            });

            // Special follow-up (<70% on recent sessions)
            var specialFollowUp = allStudents.Where(s => s.IsActive)
                .Select(s => new { Student = s, Recent = rangeSessions.Where(rs => rs.StudentId == s.Id)
                    .OrderByDescending(rs => rs.SessionDate).ThenByDescending(rs => rs.Id).Take(3).ToList() })
                .Where(x => x.Recent.Count == 3 && x.Recent.All(rs => Score(rs) < 70))
                .Select(x => new { x.Student.Id, x.Student.FullName, StudentName = x.Student.FullName,
                    CircleName = x.Student.Circle?.Name ?? "غير مسند", Contact = x.Student.FamilyContact ?? "",
                    RecentAvgGrade = Math.Round(x.Recent.Average(Score), 1), Notes = "ثلاث جلسات متتالية أقل من 70%" }).ToList();
            var plans = await _db.CirclePlans.AsNoTracking().Where(p => p.StartsOn <= today && p.Completed < p.Target).ToListAsync();
            var delayedPlans = plans.Select(p => new { p, Expected = Math.Min(1m, (decimal)(today.DayNumber - p.StartsOn.DayNumber + 1) / Math.Max(1, p.EndsOn.DayNumber - p.StartsOn.DayNumber + 1)) * p.Target })
                .Where(x => x.p.Completed < x.Expected)
                .Select(x => new { x.p.Id, x.p.CircleId, CircleName = allCircles.FirstOrDefault(c => c.Id == x.p.CircleId)?.Name ?? "", x.p.Title,
                    CompletionPercentage = Math.Round(x.p.Completed / x.p.Target * 100, 1), ExpectedPercentage = Math.Round(x.Expected / x.p.Target * 100, 1) }).ToList();
            var weekdays = new[] { "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت" };
            var patterns = rangeAttendances.Where(a => a.Status == AttendanceStatus.Absent)
                .GroupBy(a => new { a.StudentId, a.SessionDate.DayOfWeek })
                .Where(g => g.Select(a => a.SessionDate).Distinct().Count() >= 3)
                .Select(g => new { g.Key.StudentId, StudentName = allStudents.FirstOrDefault(s => s.Id == g.Key.StudentId)?.FullName ?? "",
                    FrequentDay = weekdays[(int)g.Key.DayOfWeek], Count = g.Select(a => a.SessionDate).Distinct().Count() }).ToList();

            var assessmentBreakdown = rangeSessions
                .GroupBy(s => s.Assessment)
                .ToDictionary(
                    g => SessionService.AssessmentText(g.Key),
                    g => g.Count()
                );

            return new
            {
                schemaVersion = 2,
                today = today.ToString("yyyy-MM-dd"),
                generatedAt = DateTime.UtcNow,
                pageCountsEstimated = rangeSessions.Any(s => s.Pages == null),
                from = from.ToString("yyyy-MM-dd"),
                to = to.ToString("yyyy-MM-dd"),

                // 1. KPI Cards
                totalStudents,
                totalStudentsActive,
                totalStudentsInactive,
                totalCircles,
                activeCircles,
                totalCapacity,
                capacityUtilizationRate = capacityUtilization,
                totalTeachers,
                activeTeachers,
                totalParents = totalParentsCount,
                linkedParentsCount,
                unlinkedParentsCount,
                parentLinkPercentage = parentLinkPercent,
                khatimunTotal,
                khatimunThisYear,
                khatimunThisMonth,
                huffazInIjazaCount = huffazInIjaza,

                // 2. Real-time Operations Pulse
                todayStudentsPresent,
                todayStudentsExcused,
                todayStudentsAbsent,
                todayStudentsLate,
                todayAttendanceRate,
                todayCirclesStarted,
                todayCirclesLateOrPending,
                todayTeachersPresent,
                todaySessionsCount,
                todayPagesRecited,
                todayVersesRecited,

                // 3. Range summary
                totalSessions = rangeTotalSessions,
                totalVersesRecited = rangeTotalVerses,
                studentAbsenceCount = rangeAbsenceCount,
                assessmentBreakdown,

                // 4. Quality & Performance
                topPerformingCircles,
                lowestPerformingCircles,
                totalExamsCompleted,
                examPassRate,
                qualifiedStudentsForExam,
                consecutiveAbsenceAlerts = consecutiveAbsenceAlerts.Take(15),
                monthlyAbsenceAlerts = monthlyAbsenceAlerts.Take(15),

                // 5. Specialized Programs
                khatimunAffairsCount = huffazCount,
                preacherYouthCount,
                preacherSpeechesCount,
                certificatesIssuedThisMonth = certsMonth,
                certificatesTotal = certsTotal,

                // 6. Quranic Flow
                avgDailyPagesPerStudent = dailyPagesEstimate,
                avgWeeklyPagesPerStudent = weeklyPagesEstimate,
                revisionToNewRatio = revisionRatio,
                ajzaaDistribution = new
                {
                    juz1to5,
                    juz6to10,
                    juz11to20,
                    juz21to30
                },

                // 7. Early Warnings
                specialFollowUpStudents = specialFollowUp,

                // ═══ Structured Unified Modules for Web & Mobile ═══
                kpi = new
                {
                    totalStudents,
                    activeStudents = totalStudentsActive,
                    suspendedStudents = totalStudentsInactive,
                    totalCircles,
                    activeCircles,
                    circleCapacityUtilizationRate = capacityUtilization,
                    totalTeachers,
                    activeTeachers,
                    totalParents = totalParentsCount,
                    linkedParents = linkedParentsCount,
                    unlinkedParents = unlinkedParentsCount,
                    parentLinkRate = parentLinkPercent,
                    khatimunCountYear = khatimunThisYear,
                    khatimunCountMonth = khatimunThisMonth,
                    khatimunTotal
                },
                dailyOperations = new
                {
                    studentAttendanceRateToday = todayAttendanceRate,
                    presentToday = todayStudentsPresent,
                    excusedAbsentToday = todayStudentsExcused,
                    unexcusedAbsentToday = todayStudentsAbsent,
                    lateToday = todayStudentsLate,
                    teacherAttendanceRateToday = Percentage(todayTeachersPresent, activeTeachers),
                    activeCirclesToday = todayCirclesStarted,
                    pendingOrDelayedCirclesToday = todayCirclesLateOrPending,
                    sessionsToday = todaySessionsCount,
                    pagesRecitedToday = todayPagesRecited,
                    ajzaaRecitedToday = Math.Round((double)todayPagesRecited / 20.0, 1),
                    versesRecitedToday = todayVersesRecited
                },
                quality = new
                {
                    topCircles = topPerformingCircles,
                    lowestCircles = lowestPerformingCircles,
                    completedExamsCount = totalExamsCompleted,
                    examSuccessRate = examPassRate,
                    qualifiedStudentsCount = qualifiedStudentsForExam,
                    earlyWarningConsecutiveAbsent3Days = consecutiveAbsenceAlerts.Take(15),
                    earlyWarningMonthlyAbsent10Days = monthlyAbsenceAlerts.Take(15)
                },
                specializedPrograms = new
                {
                    tathbeetCount,
                    ijazaCount = huffazInIjaza,
                    preacherYouthCount,
                    soundPathsCount = preacherSpeechesCount,
                    certificatesIssuedMonthCount = certsMonth,
                    certificatesTotal = certsTotal
                },
                quranicFlow = new
                {
                    dailyAveragePages = dailyPagesEstimate,
                    weeklyAveragePages = weeklyPagesEstimate,
                    reviewRatio = reviewPercent,
                    newMemorizationRatio = newPercent,
                    ajzaaDistribution = new Dictionary<string, int>
                    {
                        { "من 1 إلى 5 أجزاء", juz1to5 },
                        { "من 6 إلى 10 أجزاء", juz6to10 },
                        { "من 11 إلى 20 جزءاً", juz11to20 },
                        { "فوق 20 جزءاً", juz21to30 }
                    }
                },
                earlyWarnings = new
                {
                    needSpecialFollowup = specialFollowUp,
                    delayedCircles = delayedPlans,
                    patternAbsenceAlerts = patterns
                }
            };
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ReportService.GetExecutiveDashboardAsync Error] {ex.Message}");
            throw new InvalidOperationException("تعذر تحميل إحصائيات المركز. يرجى إعادة المحاولة.", ex);
        }
    }
    public static int CompletedParts(Student student) => (student.CompletedAjzaa ?? "").Split(',').Select(x => int.TryParse(x.Trim(), out var n) ? n : 0).Where(n => n >= 1 && n <= 30).Distinct().Count();
    public static double Pages(RecitationSession s) => s.Assessment == AssessmentLevel.DidNotRecite ? 0 : s.Pages ?? Math.Max(0, s.ToVerse - s.FromVerse + 1) / 15.0;
    public static double Score(RecitationSession s) => s.Score ?? s.Assessment switch { AssessmentLevel.Excellent => 95, AssessmentLevel.VeryGood => 85, AssessmentLevel.Good => 75, AssessmentLevel.Medium => 60, AssessmentLevel.Rejected => 40, _ => 0 };
    public static double Percentage(int count, int total) => total > 0 ? Math.Round(count * 100.0 / total, 1) : 0;

    public static bool HasCompletedQuran(Student student)
    {
        var parts = (student.CompletedAjzaa ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(v => int.TryParse(v.Trim(), out var number) ? number : 0).ToHashSet();
        var text = (student.PreviousQuranMemorization ?? "").Trim();
        return Enumerable.Range(1, 30).All(parts.Contains) || text is "خاتم" or "خاتم القرآن" or "كامل القرآن" or "القرآن كامل" or "القرآن كاملاً";
    }

}
