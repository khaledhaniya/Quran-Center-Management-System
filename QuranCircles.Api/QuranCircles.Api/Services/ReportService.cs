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
}
