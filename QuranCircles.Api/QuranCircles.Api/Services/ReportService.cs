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
        if (parentUser == null) return new List<Student>();

        // 1. Resolve national identity number of this user/teacher
        var idNumbersToMatch = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        if (!string.IsNullOrWhiteSpace(parentUser.Username) && parentUser.Username.All(char.IsDigit) && parentUser.Username.Trim().Length >= 7)
        {
            idNumbersToMatch.Add(parentUser.Username.Trim());
        }

        Teacher? teacher = parentUser.Teacher;
        if (teacher == null && parentUser.TeacherId.HasValue)
        {
            teacher = await _db.Teachers.FindAsync(parentUser.TeacherId.Value);
        }
        else if (teacher == null && (parentUser.Role == UserRole.Teacher || parentUser.Role == UserRole.Admin))
        {
            var uName = (parentUser.Username ?? "").Trim();
            teacher = await _db.Teachers.FirstOrDefaultAsync(t =>
                (!string.IsNullOrEmpty(t.IdentityNumber) && t.IdentityNumber == uName) ||
                (!string.IsNullOrEmpty(t.FullName) && t.FullName == parentUser.FullName));
        }

        if (teacher != null && !string.IsNullOrWhiteSpace(teacher.IdentityNumber))
        {
            idNumbersToMatch.Add(teacher.IdentityNumber.Trim());
        }

        var query = _db.Students.Include(s => s.Circle).AsQueryable();
        List<Student> matched = new();

        // 2. Strict Match by National Identity Number
        if (idNumbersToMatch.Count > 0)
        {
            matched = await query
                .Where(s => s.ParentIdentityNumber != null && idNumbersToMatch.Contains(s.ParentIdentityNumber.Trim()))
                .ToListAsync();

            // Also include explicit ParentId links only if they don't have a contradicting ParentIdentityNumber
            if (parentUser.ParentId.HasValue || parentUser.Role == UserRole.Parent)
            {
                int pId = parentUser.ParentId ?? parentUser.Id;
                var directById = await query
                    .Where(s => s.ParentId == pId || s.ParentId == parentUser.Id)
                    .ToListAsync();

                foreach (var d in directById)
                {
                    if (string.IsNullOrWhiteSpace(d.ParentIdentityNumber) || idNumbersToMatch.Contains(d.ParentIdentityNumber.Trim()))
                    {
                        if (!matched.Any(m => m.Id == d.Id))
                        {
                            matched.Add(d);
                        }
                    }
                }
            }
        }
        else if (parentUser.Role == UserRole.Parent)
        {
            int pId = parentUser.ParentId ?? parentUser.Id;
            matched = await query
                .Where(s => s.ParentId == pId || s.ParentId == parentUser.Id)
                .ToListAsync();
        }
        else
        {
            // Teacher without National ID or no children registered with that ID
            matched = new List<Student>();
        }

        return matched.GroupBy(s => s.Id).Select(g => g.First()).OrderBy(s => s.Id).ToList();
    }

    public async Task<object> GetExecutiveDashboardAsync(DateOnly from, DateOnly to)
    {
        try
        {
            var today = DateOnly.FromDateTime(DateTime.Today);
            var now = DateTime.Now;

            // 1. Core Counts
            var allStudents = await _db.Students.Include(s => s.Circle).AsNoTracking().ToListAsync();
            var allTeachers = await _db.Teachers.AsNoTracking().ToListAsync();
            var allCircles = await _db.Circles.Include(c => c.Teacher).AsNoTracking().ToListAsync();
            var allParents = await _db.Users.Where(u => u.Role == UserRole.Parent).AsNoTracking().ToListAsync();

            int totalStudents = allStudents.Count;
            int totalStudentsActive = allStudents.Count(s => s.IsActive);
            int totalStudentsInactive = allStudents.Count(s => !s.IsActive);

            int totalCircles = allCircles.Count;
            int activeCircles = allCircles.Count(c => c.IsActive);
            var dashboardSettings = await _db.SystemSettings.AsNoTracking().FirstOrDefaultAsync();
            int maxCapPerCircle = Math.Max(1, dashboardSettings?.MaxStudentsPerCircle ?? 20);
            int totalCapacity = activeCircles * maxCapPerCircle;
            double capacityUtilization = totalCapacity > 0 ? Math.Round((double)totalStudentsActive / totalCapacity * 100, 1) : 0;

            int totalTeachers = allTeachers.Count;
            int activeTeachers = allTeachers.Count(t => t.IsActive);

            // Parents linking audit
            var studentParentIds = allStudents.Where(s => s.ParentId.HasValue).Select(s => s.ParentId!.Value).ToHashSet();
            var studentParentIdNums = allStudents.Where(s => !string.IsNullOrWhiteSpace(s.ParentIdentityNumber)).Select(s => s.ParentIdentityNumber!.Trim()).ToHashSet(StringComparer.OrdinalIgnoreCase);
            var studentFamilyPhones = allStudents.Where(s => !string.IsNullOrWhiteSpace(s.FamilyContact)).Select(s => s.FamilyContact!.Trim()).ToHashSet(StringComparer.OrdinalIgnoreCase);

            int totalParentsCount = allParents.Count;
            int linkedParentsCount = allParents.Count(p =>
                (p.ParentId.HasValue && studentParentIds.Contains(p.ParentId.Value)) ||
                studentParentIds.Contains(p.Id) ||
                (!string.IsNullOrWhiteSpace(p.Username) && (studentParentIdNums.Contains(p.Username.Trim()) || studentFamilyPhones.Contains(p.Username.Trim())))
            );
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

            int khatimunThisYear = examNominations.Count(e => e.Status == "Completed" && e.NominationType == "Quran" && (e.JuzStart == 1 && e.JuzEnd == 30 && e.Result != null && e.Result.Grade >= (dashboardSettings?.PassingScoreThreshold ?? 70)) && e.ExamDate.HasValue && e.ExamDate.Value.Year == currentYear);
            int khatimunThisMonth = examNominations.Count(e => e.Status == "Completed" && e.NominationType == "Quran" && (e.JuzStart == 1 && e.JuzEnd == 30 && e.Result != null && e.Result.Grade >= (dashboardSettings?.PassingScoreThreshold ?? 70)) && e.ExamDate.HasValue && e.ExamDate.Value.Month == currentMonth && e.ExamDate.Value.Year == currentYear);

            int huffazCount = await _db.HuffazMembers.CountAsync();
            int huffazInIjaza = await _db.HuffazMembers.CountAsync(h => (h.Riwayah != null && (h.Riwayah.Contains("إجازة") || h.Riwayah.Contains("سند") || h.Riwayah.Contains("عشر"))) || (h.RevisionPlan != null && h.RevisionPlan.Contains("تثبيت")));

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
            double todayAttendanceRate = todayTotalAtt > 0 ? Math.Round((double)todayStudentsPresent / todayTotalAtt * 100, 1) : 0;

            var todaySessions = await _db.Sessions.Include(s => s.Student)
                .Where(s => s.SessionDate == today)
                .AsNoTracking()
                .ToListAsync();

            int todaySessionsCount = todaySessions.Count;
            int todayVersesRecited = todaySessions.Where(s => s.Assessment != AssessmentLevel.DidNotRecite).Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));
            int todayPagesRecited = Math.Max(0, (int)Math.Round((double)todayVersesRecited / 15.0));

            // Teacher Presence & Circle Start Status (Implicit Detection)
            var todayStartedCircleIds = todaySessions.Select(s => s.Student != null ? s.Student.CircleId : null).Where(c => c.HasValue).Select(c => c!.Value).ToHashSet();
            foreach (var a in todayAttendances.Where(a => a.CircleId > 0))
            {
                todayStartedCircleIds.Add(a.CircleId);
            }

            int todayCirclesStarted = allCircles.Count(c => c.IsActive && todayStartedCircleIds.Contains(c.Id));
            int todayCirclesLateOrPending = Math.Max(0, activeCircles - todayCirclesStarted);
            int todayTeachersPresent = allCircles.Where(c => todayStartedCircleIds.Contains(c.Id) && c.TeacherId.HasValue).Select(c => c.TeacherId!.Value).Distinct().Count();

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
                var cSess = rangeSessions.Where(s => s.Student != null && s.Student.CircleId == c.Id).ToList();
                int cPresent = cAtts.Count(a => a.Status == AttendanceStatus.Present);
                int cTotalAtt = cAtts.Count;
                double rate = cTotalAtt > 0 ? Math.Round((double)cPresent / cTotalAtt * 100, 1) : 0;
                int verses = cSess.Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));

                return new
                {
                    c.Id,
                    c.Name,
                    CircleName = c.Name,
                    TeacherName = c.Teacher != null ? c.Teacher.FullName : "غير محدد",
                    StudentsCount = allStudents.Count(s => s.CircleId == c.Id && s.IsActive),
                    AttendanceRate = rate,
                    SessionsCount = cSess.Count,
                    VersesRecited = verses
                };
            }).ToList();

            var topPerformingCircles = circlePerformance.OrderByDescending(c => c.AttendanceRate).ThenByDescending(c => c.VersesRecited).Take(5).ToList();
            var lowestPerformingCircles = circlePerformance.OrderBy(c => c.AttendanceRate).ThenBy(c => c.SessionsCount).Take(5).ToList();

            // Exam indicators
            int totalExamsCompleted = examNominations.Count(e => e.Status == "Completed");
            int passedExams = examNominations.Count(e => e.Status == "Completed" && e.Result != null && e.Result.Grade >= (dashboardSettings?.PassingScoreThreshold ?? 70));
            double examPassRate = totalExamsCompleted > 0 ? Math.Round((double)passedExams / totalExamsCompleted * 100, 1) : 0;
            int qualifiedStudentsForExam = allStudents.Count(s => s.IsActive && s.CompletedAjzaa != null && s.CompletedAjzaa.Length > 0);

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
            int preacherYouthCount = await _db.TalentRecords.Select(t => t.StudentId).Distinct().CountAsync();
            int preacherSpeechesCount = await _db.TalentRecords.CountAsync();
            var courseEnrollments = await _db.CourseEnrollments.AsNoTracking().ToListAsync();
            int certsMonth = courseEnrollments.Count(e => e.CertificateCode != null && e.CertificateDate.HasValue && e.CertificateDate.Value.Month == currentMonth && e.CertificateDate.Value.Year == currentYear)
                + examNominations.Count(e => e.Status == "Completed" && e.ExamDate.HasValue && e.ExamDate.Value.Month == currentMonth && e.ExamDate.Value.Year == currentYear);
            int certsTotal = courseEnrollments.Count(e => !string.IsNullOrEmpty(e.CertificateCode)) + totalExamsCompleted;

            // 6. Quranic Flow & Cumulative Memorization
            int memorizationCount = rangeSessions.Count(s => s.RecitationType == RecitationType.Memorization && s.Assessment != AssessmentLevel.DidNotRecite);
            int revisionCount = rangeSessions.Count(s => s.RecitationType == RecitationType.Revision && s.Assessment != AssessmentLevel.DidNotRecite);
            double revisionRatio = memorizationCount > 0 ? Math.Round((double)revisionCount / memorizationCount, 2) : 0;
            double reviewPercent = Percentage(revisionCount, revisionCount + memorizationCount);
            double newPercent = Percentage(memorizationCount, revisionCount + memorizationCount);
            int rangeDays = Math.Max(1, to.DayNumber - from.DayNumber + 1);
            // Page counts are estimates (15 verses/page), not exact Mushaf page positions.
            double dailyPagesEstimate = totalStudentsActive > 0 ? Math.Round(rangeTotalVerses / 15.0 / totalStudentsActive / rangeDays, 2) : 0;
            double weeklyPagesEstimate = Math.Round(dailyPagesEstimate * 7, 2);

            int juz1to5 = allStudents.Count(s => {
                int count = s.CompletedAjzaa != null ? s.CompletedAjzaa.Split(',', StringSplitOptions.RemoveEmptyEntries).Length : 0;
                return count >= 1 && count <= 5;
            });
            int juz6to10 = allStudents.Count(s => {
                int count = s.CompletedAjzaa != null ? s.CompletedAjzaa.Split(',', StringSplitOptions.RemoveEmptyEntries).Length : 0;
                return count >= 6 && count <= 10;
            });
            int juz11to20 = allStudents.Count(s => {
                int count = s.CompletedAjzaa != null ? s.CompletedAjzaa.Split(',', StringSplitOptions.RemoveEmptyEntries).Length : 0;
                return count >= 11 && count <= 20;
            });
            int juz21to30 = allStudents.Count(s => {
                int count = s.CompletedAjzaa != null ? s.CompletedAjzaa.Split(',', StringSplitOptions.RemoveEmptyEntries).Length : 0;
                return count >= 21;
            });

            // Special follow-up (<70% on recent sessions)
            var specialFollowUp = allStudents
                .Where(s => s.IsActive && rangeSessions.Where(rs => rs.StudentId == s.Id)
                    .OrderByDescending(rs => rs.SessionDate).Take(3).Count() == 3 &&
                    rangeSessions.Where(rs => rs.StudentId == s.Id).OrderByDescending(rs => rs.SessionDate).Take(3)
                        .All(rs => rs.Assessment is AssessmentLevel.Rejected or AssessmentLevel.Medium))
                .Take(10)
                .Select(s => new
                {
                    s.Id,
                    s.FullName,
                    CircleName = s.Circle?.Name ?? "غير مسند",
                    Contact = s.FamilyContact ?? s.StudentMobile ?? "",
                    Notes = "انخفاض درجات التسميع ويحتاج خطة علاجية"
                })
                .ToList();

            var assessmentBreakdown = rangeSessions
                .GroupBy(s => s.Assessment)
                .ToDictionary(
                    g => SessionService.AssessmentText(g.Key),
                    g => g.Count()
                );

            return new
            {
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
                    tathbeetCount = huffazCount,
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
                    delayedCircles = lowestPerformingCircles,
                    patternAbsenceAlerts = consecutiveAbsenceAlerts.Take(5)
                }
            };
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ReportService.GetExecutiveDashboardAsync Error] {ex.Message}");
            throw new InvalidOperationException("تعذر تحميل إحصائيات المركز. يرجى إعادة المحاولة.", ex);
        }
    }
    public static double Percentage(int count, int total) => total > 0 ? Math.Round(count * 100.0 / total, 1) : 0;

    public static bool HasCompletedQuran(Student student)
    {
        var parts = (student.CompletedAjzaa ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(v => int.TryParse(v.Trim(), out var number) ? number : 0).ToHashSet();
        var text = (student.PreviousQuranMemorization ?? "").Trim();
        return Enumerable.Range(1, 30).All(parts.Contains) || text is "خاتم" or "خاتم القرآن" or "كامل القرآن" or "القرآن كامل" or "القرآن كاملاً";
    }

}
